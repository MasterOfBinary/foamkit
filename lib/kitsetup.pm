#
# FOAMkit: Project management for OpenFOAM
#
# kitsetup.pm - Subroutines for setting up FOAMkit.
#

package kitsetup;

use strict;
use warnings;

use foamkitenv;
use kittools;

use base 'Exporter';
our @EXPORT = qw/ get_setup_dirs is_dir_setup setup_dir cleanup_dir /;

my %setup_dirs = ();

#
# Gets the directories that can be setup along with their friendly names.
#
sub get_setup_dirs
{
  return %setup_dirs unless (!%setup_dirs);

  my %dirs = ();

  my %env = get_foamkit_env();

  # The directories in SOURCE are the ones we want to look at
  my $source_dir = "$env{FOAMKIT_DIR}/SOURCE";
  my @source_dirs = read_files_in_dir($source_dir, 0); # 0=not recursive

  # For each file there should be a foamkit.dat with, in particular,
  # the friendly name
  foreach my $dir (@source_dirs)
  {
    my %data = load_dat_file("$dir/foamkit.dat");

    # Strip off the full path name
    $dir =~ s:^$source_dir/::g;

    if (defined $data{FRIENDLY_NAME} and "$data{FRIENDLY_NAME}" ne "")
    {
      $dirs{$dir} = $data{FRIENDLY_NAME};
    }
    else
    {
      print STDERR "WARNING: Invalid or nonexistant foamkit.dat file in $dir.\n";
    }
  }

  %setup_dirs = %dirs;

  return %dirs;
}

#
# Returns the subdir if the directory has already been setup, 0 otherwise.
#
sub is_dir_setup
{
  my ($dir) = @_;

  my %setup_data = get_setup_data();
  my $key = $dir . "_setup";
  return 0 unless (defined $setup_data{$key} && $setup_data{$key} ne "0");
  return $setup_data{$key};
}

#
# Sets up a directory by copying its files into the main foamkit dir.
#
sub setup_dir
{
  my ($dir, $force, $usecurrent) = @_;
  
  my $friendly_name = $setup_dirs{$dir};

  if (!$force and is_dir_setup($dir))
  {
    print STDERR "Already setup! Clean up first to start over.\n";
    return 0;
  }

  print "Setting up $friendly_name... \n";
  
  # If there are more than one directory, ask which one to use
  my $subdir;
  if ($usecurrent)
  {
    $subdir = is_dir_setup($dir);
  }
  else
  {
    my @subfiles = read_files_in_dir("SOURCE/$dir", 0); # 0=not recursive
    my %subdirs = ();
    foreach (@subfiles)
    {
      # Directory named "common" is reserved
      if ("$_" ne "SOURCE/$dir/common" && -d "$_")
      {
        # Read the foamkit.dat file
        my %data = load_dat_file("$_/foamkit.dat");
        if (defined $data{FRIENDLY_NAME} and "$data{FRIENDLY_NAME}" ne "")
        {
          $subdirs{$_} = $data{FRIENDLY_NAME};
        }
        else
        {
          print STDERR "WARNING: Invalid or nonexistant foamkit.dat file in $_.\n";
        }
        s:SOURCE/$_/::;
      }
    }
    
    if (scalar keys %subdirs == 0)
    {
      print "No $friendly_name found!\n";
      return 0;
    }
    elsif (scalar keys %subdirs == 1)
    {
      $subdir = "$_" and print "Using $subdirs{$_}.\n" foreach (keys %subdirs);
      $subdir =~ s:^SOURCE/$dir/::;
    }
    else
    {
      # Prompt which one
      print "\nChoose which $friendly_name.\n\n";
      my $i = 1;
      my @subdirs_sorted = sort keys %subdirs;
      print "$i $subdirs{$_}\n" and $i++ foreach (@subdirs_sorted);
      
      my $idx = 0;
      
      while (1)
      {
        print "\nSelect an option: ";
        my $ans = <STDIN>;
        chomp $ans;
        if (grep(/^$ans$/, (1 .. scalar @subdirs_sorted)))
        {
          $idx = $ans;
          last;
        }
        print "I don't know what that means.\n";
      }
      
      $subdir = $subdirs_sorted[$idx - 1];
      print "\nUsing $subdirs{$subdir}.\n";
      $subdir =~ s:^SOURCE/$dir/::;
    }
  }
  
  # Copy the necessary files, if there's a common directory do it first
  if (-d "SOURCE/$dir/common" && !copy_files("$dir/common"))
  {
    print "Failed!\n";
  }
  
  if (copy_files("$dir/$subdir"))
  {
    add_setup_data(($dir . "_setup" => "$subdir"));
    print "Done.\n";
  }
  else
  {
    print "Failed!\n";
  }

  return 1;
}

#
# Cleans up a directory by removing all files originally copied.
#
sub cleanup_dir
{
  my ($dir, $force) = @_;

  my $friendly_name = $setup_dirs{$dir};

  my $subdir = is_dir_setup($dir);
  if (!$subdir)
  {
    print STDERR "Not setup!\n";
    return 0;
  }

  # Prompt before deleting everything
  print "All $friendly_name created from $subdir and common will be deleted, including any files you changed! Other files will be left alone.\n";
  return 0 unless ($force or strong_confirm());

  # Ready to delete everything
  print "Cleaning up $friendly_name...\n";
  remove_files("$dir/$subdir");
  remove_files("$dir/common");
  add_setup_data(($dir . "_setup" => 0));
  print "Done.\n";

  return 1;
}

1;

