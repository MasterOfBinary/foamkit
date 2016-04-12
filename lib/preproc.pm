#
# FOAMkit: Project management for OpenFOAM
#
# preproc.pm - Subroutines for preprocessing.
#

package preproc;

use strict;
use warnings;

use foamkitenv;
use kittools;
use kitsetup;

use base 'Exporter';
our @EXPORT = qw/ create_mesh cleanup_mesh /;

my @creation_files = qw: 0/cellToRegion 0/yPlus 0 constant/polyMesh/boundary constant/polyMesh/cellZones constant/polyMesh/faces constant/polyMesh/faceZones constant/polyMesh/neighbour constant/polyMesh/owner constant/polyMesh/points constant/polyMesh/pointZones constant/polyMesh/sets/region0 constant/polyMesh/sets/region1 constant/polyMesh/sets constant/polyMesh constant :;

#
# Convert the mesh from ANSYS Fluent.
#
sub create_mesh
{
  my %env = get_foamkit_env();
  
  # Everything should be setup
  print "Scripts not setup!\n" and return 0 unless is_dir_setup("scripts");
  print "Initial fields not setup!\n" and return 0 unless is_dir_setup("initial");
  print "Mesh not setup!\n" and return 0 unless is_dir_setup("mesh");
  print "Case not setup!\n" and return 0 unless is_dir_setup("case");
  
  # Get the output directory name
  my $outdir = "$env{SIM_DIR}/preproc_" . get_timestamp();

  # Create the output directory
  mkdir "$outdir", 0755;
  
  # All output should go both to the screen and to a file
  my $logfile;
  open $logfile, ">", "$outdir/preproc.txt";
  log_text($logfile, "CONVERTING MESH\n");
  log_text($logfile, "===============\n\n");
  
  my $starttime = time;

  log_text($logfile, "Start time:       " . get_timestamp(1) . "\n");
  log_text($logfile, "Output directory: $outdir\n");
  log_text($logfile, "\n");

  # Do simulation: there should be a run.sh script in the preproc directory
  run_command("bash $env{FOAMKIT_DIR}/preproc/preproc.sh $outdir", $env{FOAMKIT_DIR}, $logfile);

  my $endtime = time;
  my $duration = $endtime - $starttime;

  log_text($logfile, "\nFinish time:      " . get_timestamp(1) . "\n");
  log_text($logfile, "Duration:         " . format_timespan($duration) . "\n");

  close $logfile;

  return 1;
}

#
# Cleans up everything created by the mesh creation.
#
sub cleanup_mesh
{
  my ($force) = @_;
  
  # Prompt before deleting everything
  print "All mesh files created will be deleted, including any files you changed! Other files will be left alone.\n";
  return 0 unless ($force or strong_confirm());
  
  for my $file (@creation_files)
  {
    if (-d "$file")
    {
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
      # Remove the file
      print "Removing $file... ";
      if (unlink $file)
      {
        print "Done.\n";
      }
      else
      {
        print "Failed.\n";
      }
    }
  }

  return 1;
}
