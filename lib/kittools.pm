#
# FOAMkit: Project management for OpenFOAM
#
# kittools.pm - Tools for FOAMkit.
#

package kittools;

use strict;
use warnings;

use Cwd;
use File::Copy;
use POSIX qw(strftime);

use foamkitenv;

use base 'Exporter';
our @EXPORT = qw/ read_files_in_dir copy_files remove_files strong_confirm get_timestamp format_timespan run_command log_text /;

#
# Reads all files in specified directory, optionally reading recursively.
#
sub read_files_in_dir
{
  my ($dir, $recursive) = @_;

  my @files = ();

  opendir(my $dirhdl, $dir) or return @files;

  while (my $file = readdir($dirhdl))
  {
    next if $file =~ /^\.\.?$/;

    $file = "$dir/$file";
    push @files, $file;

    # Recurse
    if ($recursive && (-d "$file"))
    {
      my @subfiles = read_files_in_dir("$file", 1);
      for my $subfile (@subfiles)
      {
        push @files, "$subfile";
      }
    }
  }

  closedir($dirhdl);

  return @files;
}

#
# Copies files from source directory to root directory.
#
sub copy_files
{
  my ($source) = @_;

  my %env = get_foamkit_env();

  my $cwdorig = getcwd();
  chdir("$env{CASE_DIR}");
  my @files = read_files_in_dir("SOURCE/$source", 1);

  # Copy the files and directories
  for my $file (@files)
  {
    # Ignore any foamkit.dat files and hidden files
    next if $file =~ /foamkit\.dat$/;
    next if $file =~ m:/\..*:;

    if (-d "$file")
    {
      $file =~ s:^SOURCE/$source/::;

      # Simply make the directory
      print "Creating $file... ";
      mkdir "$file", 0755;
      print "Done.\n";
    }
    elsif (-f "$file")
    {
      my $newfile = $file;
      $newfile =~ s:^SOURCE/$source/::;

      # If it has a .tmpl extension open it and replace stuff between %%
      if ($newfile =~ /\.tmpl$/)
      {
        $newfile =~ s/\.tmpl$//;
        print "Generating $newfile... ";
        unless (open OUTFILE, ">", "$newfile")
        {
          print STDERR "Failed.\n";
          next;
        }
        unless (open INFILE, '<', "$file")
        {
          print STDERR "Failed.\n";
          close OUTFILE;
          next;
        }

        while (my $line = <INFILE>)
        {
          foreach my $key (%env)
          {
            $line =~ s/%%$key%%/$env{$key}/g;
          }
          print OUTFILE $line;
        }

        close INFILE;
        close OUTFILE;

        print "Done.\n";
      }
      else
      {
        # Just copy the file
        print "Copying $newfile... ";
        copy("$file", "$newfile");
        print "Done.\n";
      }

      # Set relevant permissions
      chmod 0755, $newfile if ($newfile =~ /\.sh$/);
      chmod 0644, $newfile unless ($newfile =~ /\.sh$/);
    }
  }

  chdir("$cwdorig");

  return 1;
}

#
# Removes files copied from source directory.
#
sub remove_files
{
  my ($source) = @_;

  my %env = get_foamkit_env();

  my $cwdorig = getcwd();
  chdir("$env{CASE_DIR}");
  my @files = read_files_in_dir("SOURCE/$source", 1);

  my @dirs = ();

  # Remove the files in reverse order so directories are removed after the files in them
  for my $file (sort {$b cmp $a} @files)
  {
    # Ignore any foamkit.dat files and hidden files
    next if $file =~ /foamkit\.dat$/;
    next if $file =~ m:/\..*:;

    if (-d "$file")
    {
      $file =~ s:^SOURCE/$source/::;

      print "Removing $file... ";
      if (rmdir $file)
      {
        print "Done.\n";
      }
      else
      {
        print "Failed.\n";
      }
    }
    elsif (-f "$file")
    {
      my $newfile = $file;
      $newfile =~ s:^SOURCE/$source/::;
      $newfile =~ s/\.tmpl$//;

      # Remove the file
      print "Removing $newfile... ";
      if (unlink $newfile)
      {
        print "Done.\n";
      }
      else
      {
        print "Failed.\n";
      }
    }
  }

  chdir("$cwdorig");

  return 1;
}

#
# Prompts and requires a random string before continuing. Use if something potentially
# disastrous could happen.
#
sub strong_confirm
{
  while (1)
  {
    print "Really continue [y/N]? ";
    my $ans = <STDIN>;
    chomp $ans;
    return 0 if ($ans =~ /^$/ || $ans =~ /^n$/i);
    last if ($ans =~ /^y$/i);
    print "I don't know what that means.\n";
  }

  # Random string
  my @chars = ("A".."Z", "a".."z", "0".."9");
  my $string;
  $string .= $chars[rand @chars] for 1..6;

  print "Enter the random string $string to continue: ";
  my $ans = <STDIN>;
  chomp $ans;
  return 1 if ($ans =~ /^$string$/);

  print "Invalid answer.\n";
  return 0;
}

#
# Returns a timestamp that can be used for uniquely creating directories.
# Optionally return a log format string.
#
sub get_timestamp
{
  my ($long) = @_;

  if ($long)
  {
    return strftime("%c", localtime);
  }
  else
  {
    return strftime("%y%m%d_%H%M%S", localtime);
  }
}

#
# Given a number of seconds elapsed, formats it into HH:MM:SS format. There's
# actually likely something in Perl that can do this but I couldn't find one
# right away and it's pretty trivial to implement.
sub format_timespan
{
  my ($duration) = @_;

  my $ret = "";

  my $seconds = $duration % 60;
  $duration /= 60;
  my $minutes = $duration % 60;
  $duration /= 60;
  my $hours = $duration % 24;
  $duration /= 24;
  my $days = $duration;

  $ret = sprintf "%d days, ", $days if (int $days > 0);
  $ret .= sprintf "%02d:", $hours if (int $hours > 0);
  $ret .= sprintf "%02d:%02d", $minutes, $seconds;

  return $ret;
}

sub run_command
{
  my ($command, $directory, $logfile) = @_;

  my %env = get_foamkit_env();

  my $cmd = "cd $directory; $command 2>&1";
  open(CMD, "$cmd |") or (print "Can't run '$cmd'\n$!\n" and return 0);

  while (<CMD>) {
    print "$_";
    print $logfile "$_" if $logfile;
  }

  close CMD;
}

#
# Logs text to the screen as well as to a file.
#
sub log_text
{
  my ($fh, $text) = @_;

  print $fh $text;
  print $text;
}

1;

