#!/usr/bin/env perl
#
# FOAMkit: Project management for OpenFOAM
#
# foamkit.pl - Main script for FOAMkit.
#

use strict;
use warnings;

use Cwd;
use Getopt::Std;

use lib "$ENV{FOAMKIT_ROOT}/lib";
use foamkitenv;
use kitsetup;
use sim;
use postproc;
use preproc;
use Scalar::Util qw(looks_like_number);

# Check command line options
my $force = 0; # Force cleanup and setup without prompt (dangerous! for debugging only!)
my $casedir = getcwd();

my %options = ();
getopts("fc:", \%options);

$force = $options{f} if defined $options{f};
$casedir = $options{c} if defined $options{c};

if (!init_foamkit($casedir))
{
  exit 1;
}

my %env = get_foamkit_env();

my $header_text = q'------------------------------------------------------------------------------
| =========                 |                                                |
| \\\\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox          |
|  \\\\    /   O peration     | Version:  3.0.x                                |
|   \\\\  /    A nd           | Web:      www.OpenFOAM.org                     |
|    \\\\/     M anipulation  |                                                |
------------------------------------------------------------------------------
|                                                                            |
| FOAMkit: Project management for OpenFOAM 3.0.x                             |
|                                                                            |
------------------------------------------------------------------------------
';

print $header_text;

# Print some stuff
print "\nSETTINGS\n========\n\n";
print "Case dir:       $env{CASE_DIR}\n";
print "FOAMkit dir:    $env{FOAMKIT_DIR}\n";
print "Simulation dir: $env{SIM_DIR}\n";
print "OpenFOAM dir:   $env{OPENFOAM_DIR}\n";
print "Num processes:  $env{NUM_PROCS}\n";

print "\nWARNING: Forcing setup and cleanup without prompt! Files may be deleted or overwritten!\n" if $force;

my @setup_dirs_available = ();

# TODO check for command line arguments here

menu();

sub create_menu_text
{
  load_setup_data();

  my $menu_text = q'
MENU
====

0.  Quit

Kit setup and cleanup:

';

  # Get all the directories
  my %setup_dirs = get_setup_dirs();

  # Add the directories to the command line
  my $index = 1;
  @setup_dirs_available = ();
  foreach my $dir (sort keys %setup_dirs)
  {
    $menu_text .= "$index.  Setup $setup_dirs{$dir}";
    push @setup_dirs_available, $dir;

    # Notify user if it's setup already
    $menu_text .= " (" . is_dir_setup($dir) . " already setup)" if is_dir_setup($dir);
    $menu_text .= "\n";

    $index++;
  }
  $index = 10 - (scalar @setup_dirs_available);
  foreach my $dir (@setup_dirs_available)
  {
    $menu_text .= "$index.  Cleanup $setup_dirs{$dir}";

    # Notify user if it's not setup already
    $menu_text .= " (not setup)" unless is_dir_setup($dir);
    $menu_text .= "\n";

    $index++;
  }

  $menu_text .= q'
Pre-processing:

10. Convert mesh from ANSYS
19. Cleanup pre-processing

Simulation:

20. Reset initial fields
21. Run simulation';

  my $running = is_sim_running();
  my $lastsim = get_last_sim_number();

  $lastsim = "(no previous simulations)" if $lastsim =~ /^$/;

  $menu_text .= " (currently running)" if $running;
  $menu_text .= "\n22. Monitor simulation $lastsim";
  $menu_text .= " (not running)" unless $running;
  $menu_text .= "\n23. End simulation $lastsim";
  $menu_text .= " (not running)" unless $running;
  $menu_text .= "\n24. Continue simulation $lastsim";
  $menu_text .= " (currently running)" if $running;

  $menu_text .= q'

Post-processing:

30. Post-process

';

  return $menu_text;
}

sub menu
{
  while (1)
  {
    print create_menu_text();
    print "Select an option: ";
    my $line = <STDIN>;
    chomp $line;
    run_option($line);
  }
}

sub run_options
{
  my @commands = @_;

  for my $cmd (@commands)
  {
    return 0 if (!run_option($cmd));
  }

  # All commands successful
  return 1;
}

sub run_option
{
  my ($cmd) = @_;

  # Quit?
  exit 0 if ($cmd eq "0");

  print STDERR "No option selected.\n" and return 0 if ($cmd eq "");

  unless (looks_like_number($cmd))
  {
    print STDERR "Invalid command.\n";
    return 0; # No such command
  }

  print "\n";

  # Commands 1 - 9 are for kit setup and cleanup
  if ($cmd <= 9)
  {
    my $num_setup_dirs = scalar @setup_dirs_available;
    if ($cmd <= $num_setup_dirs)
    {
      my $dir = $setup_dirs_available[$cmd - 1];
      return setup_dir($dir, $force);
    }
    elsif ($cmd >= 10 - $num_setup_dirs)
    {
      my $dir = $setup_dirs_available[$num_setup_dirs - 10 + $cmd];
      return cleanup_dir($dir, $force);
    }
  }
    
  # Commands 10 - 19 are reserved for pre-processing
  return create_mesh() if ($cmd eq "10");
  return cleanup_mesh($force) if ($cmd eq "19");

  # Commands 20 - 29 are reserved for simulation
  return reset_initial_fields() if ($cmd eq "20");
  return run_simulation() if ($cmd eq "21");
  return monitor_simulation() if ($cmd eq "22");
  return end_simulation() if ($cmd eq "23");
  return continue_simulation() if ($cmd eq "24");

  # Commands 30 - 39 are reserved for post-processing
  return postprocess() if ($cmd eq "30");

  print STDERR "Invalid command.\n";
  return 0; # No such command
}

