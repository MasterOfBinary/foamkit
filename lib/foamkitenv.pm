#
# FOAMkit: Project management for OpenFOAM
#
# foamkitenv.pm - Loads environmental variables into the Perl environment.
#

package foamkitenv;

use strict;
use warnings;

use Cwd;
use Scalar::Util qw(looks_like_number);

use base 'Exporter';
our @EXPORT = qw/ init_foamkit get_foamkit_env get_setup_data add_setup_data load_dat_file load_setup_data /;

my %env = ( );
my %data = ( ); # Data for setup and stuff, will be saved to disk

#
# Checks that an environment variable is nonempty, throws an error if it is.
#
sub check_nonempty
{
  my ($value, $varname) = @_;

  if ("$value" eq "")
  {
    print STDERR "$varname environment variable not set. Did you source the foamkitenv.sh file?\n";
    return 0;
  } 

  return 1;
}

#
# Checks that an environmental variable contains a valid directory, gives an error if not.
#
sub check_dir_exists
{
  my ($value, $varname, $filename) = @_;

  # First check it actually exists
  return undef unless check_nonempty(@_);

  # Now check directory exists
  unless (-d "$value")
  {
    print STDERR "$varname does not point to a valid directory. Check that it is set correctly.\n";
    return 0;
  }

  # Then check the file or directory exists
  unless ("$filename" eq "" || -f "$value/$filename" || -d "$value/$filename")
  {
    print STDERR "$varname does not look like the right directory. Check that it is set correctly.\n";
    return 0;
  }

  return 1;
}

#
# Checks that an environment variable looks like a number.
#
sub check_numeric
{
  my ($value, $varname) = @_;

  unless (looks_like_number($value))
  {
    print STDERR "$varname doesn't look like a number. Check that it is set correctly.\n";
    return 0;
  }

  return 1;
}

#
# Checks that an environment variable is a boolean value (0/1/true/false).
#
sub check_boolean
{
  my ($value, $varname) = @_;

  unless ($value =~ /^0$/ or $value =~ /^1$/ or $value =~ /^true$/i or $value =~ /^false$/i or $value =~ /^yes$/i or $value =~ /^no$/i)
  {
    print STDERR "$varname doesn't look like a boolean value. Check that it is set correctly.\n";
    return 0;
  }

  return 1;
}

sub get_boolean_value
{
  my ($value) = @_;

  return 1 if ($value =~ /^1$/ or $value =~ /^true$/i or $value =~ /^yes$/i);
  return 0;
}

#
# Checks that all environment variables exist and are valid.
#
sub check_foamkit_env
{
  my ($casedir) = @_;

  %env = ();

  # Get the directory the source files will be
  $env{CASE_DIR} = "$casedir";
  unless (-d "$casedir/SOURCE")
  {
    print "$casedir is not a valid case directory. Check that it exists and contains a SOURCE/ directory.\n";
    return 0;
  }

  $ENV{FOAMKIT_SIM} =~ s/%%CASE_DIR%%/$casedir/;

  return 0 unless check_dir_exists("$ENV{FOAMKIT_ROOT}", "FOAMKIT_ROOT", "foamkitenv.sh");
  return 0 unless check_dir_exists("$ENV{FOAMKIT_SIM}", "FOAMKIT_SIM", "");
  return 0 unless check_dir_exists("$ENV{FOAMKIT_OF_ROOT}", "FOAMKIT_OF_ROOT", "Allwmake");
  return 0 unless check_nonempty("$ENV{FOAMKIT_OF_VERSION}", "FOAMKIT_OF_VERSION");
  return 0 unless check_numeric("$ENV{FOAMKIT_NUM_PROCS}", "FOAMKIT_NUM_PROCS");

  return 0 unless check_boolean("$ENV{FOAMKIT_CONTROL_VARIABLE_TIMESTEP}", "FOAMKIT_CONTROL_VARIABLE_TIMESTEP");
  return 0 unless check_nonempty("$ENV{FOAMKIT_CONTROL_TIMESTEP}", "FOAMKIT_CONTROL_TIMESTEP");
  return 0 unless check_numeric("$ENV{FOAMKIT_CONTROL_SIM_TIME}", "FOAMKIT_CONTROL_SIM_TIME");

  # General kit settings
  $env{FOAMKIT_DIR} = "$ENV{FOAMKIT_ROOT}";
  $env{SIM_DIR} = "$ENV{FOAMKIT_SIM}";
  $env{OPENFOAM_DIR} = "$ENV{FOAMKIT_OF_ROOT}";
  $env{OPENFOAM_VERSION} = "$ENV{FOAMKIT_OF_VERSION}";
  $env{NUM_PROCS} = "$ENV{FOAMKIT_NUM_PROCS}";

  # Control settings
  $env{CONTROL_VARIABLE_TIMESTEP} = get_boolean_value($ENV{FOAMKIT_CONTROL_VARIABLE_TIMESTEP}) ? "yes" : "no";
  $env{CONTROL_TIMESTEP} = "$ENV{FOAMKIT_CONTROL_TIMESTEP}";
  $env{CONTROL_SIM_TIME} = "$ENV{FOAMKIT_CONTROL_SIM_TIME}";


  $env{DATA_FILE} = "$env{CASE_DIR}/foamkit.dat";

  return 1;
}

#
# Checks all environment variables and loads the setup data.
#
sub init_foamkit
{
  my ($casedir) = @_;

  return 0 unless check_foamkit_env($casedir);
  return load_setup_data();
}

#
# Gets the environment variables.
#
sub get_foamkit_env
{
  return %env;
}

#
# Gets the setup data. This data can change at any time so this function should
# be called every time it's needed.
#
sub get_setup_data
{
  return %data;
}

#
# Adds data about setup. This will be saved to disk so it's preferable to add
# a bunch at once.
#
sub add_setup_data
{
  my (%newdata) = @_;

  # Add all to the existing hash
  foreach my $key (keys %newdata)
  {
    $data{$key} = $newdata{$key};
  }

  # Now save it all to the data file
  unless (open FILE, ">", "$env{DATA_FILE}")
  {
    print STDERR "Could not open $env{DATA_FILE} for writing. Data has not been saved.\n";
    return 0;
  }

  # Write key = value
  foreach my $key (keys %data)
  {
    print FILE "$key = $data{$key}\n";
  }

  close FILE;

  return 1;
}

#
# Loads the foamkit.dat file into the %data hash.
#
sub load_setup_data
{
  %data = load_dat_file("$env{DATA_FILE}");

  return 1;
}

#
# Loads key/value pairs from a .dat file into a hash.
#
sub load_dat_file
{
  my ($filename) = @_;

  my %data = ();

  unless (open FILE, '<', $filename)
  {
    # Probably doesn't exist, error
    return %data;
  }

  while (my $line = <FILE>)
  {
    # Line should be key = value
    chomp $line;
    next if ($line =~ /^\s*$/);
    unless ($line =~ /^(.*?)\s?=\s?(.*)/)
    {
      print STDERR "WARNING: Invalid line in data file.\n";
      next;
    }

    $data{$1} = $2;
  }

  close FILE;
  return %data;
}

1;
