#
# FOAMkit: Project management for OpenFOAM
#
# postproc.pm - Subroutines for postprocessing.
#

package postproc;

use strict;
use warnings;

use List::Util qw( max );

use foamkitenv;
use kittools;
use kitsetup;
use sim;

use base 'Exporter';
our @EXPORT = qw/ postprocess is_sim_running get_last_sim get_last_sim_number /;

#
# Run postprocessing.
#
sub postprocess
{
  my %env = get_foamkit_env();

  # Everything should be setup
  print "Scripts not setup!\n" and return 0 unless is_dir_setup("scripts");
  print "Mesh not setup!\n" and return 0 unless is_dir_setup("mesh");
  print "Case not setup!\n" and return 0 unless is_dir_setup("case");

  if (is_sim_running())
  {
    print STDERR "There is already something running! If you've killed the process manually, remove the simulation_running line in foamkit.dat and try again.\n";
    return 0;
  }

  # Get the output directory name
  my $outdir = get_last_sim();

  my $logfile;
  open $logfile, ">", "$outdir/postproc.txt";

  my $starttime = time;

  log_text($logfile, "POST-PROCESSING\n");
  log_text($logfile, "===============\n\n");
  log_text($logfile, "Start time:       " . get_timestamp(1) . "\n");
  log_text($logfile, "\n");

  run_command("bash $env{FOAMKIT_DIR}/postproc/postproc.sh $outdir", $env{FOAMKIT_DIR});

  my $endtime = time;
  my $duration = $endtime - $starttime;

  # Get the total size of files copied
  my $dirsize = `du -hs $outdir`;
  chomp $dirsize;
  $dirsize =~ s:\s+$outdir$::;

  log_text($logfile, "\nOutput size:      $dirsize\n");
  log_text($logfile, "Finish time:      " . get_timestamp(1) . "\n");
  log_text($logfile, "Duration:         " . format_timespan($duration) . "\n");

  close $logfile;

  return 1;
}

1;

