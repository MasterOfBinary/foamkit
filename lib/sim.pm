#
# FOAMkit: Project management for OpenFOAM
#
# sim.pm - Subroutines for running simulation.
#

package sim;

use strict;
use warnings;

use List::Util qw( max );

use foamkitenv;
use kittools;
use kitsetup;

use base 'Exporter';
our @EXPORT = qw/ reset_initial_fields run_simulation monitor_simulation end_simulation continue_simulation is_sim_running get_last_sim get_last_sim_number /;

#
# Resets the 0 directory.
#
sub reset_initial_fields
{
  my %env = get_foamkit_env();

  # Simply force the setup of the initial directory
  setup_dir("initial", 1, 1);
}

#
# Runs a simulation.
#
sub run_simulation
{
  my %env = get_foamkit_env();

  # Get the output directory name
  my $simnum = get_sim_number();
  my $outdir = "$env{SIM_DIR}/sim${simnum}_" . get_timestamp();

  # Create the output directory
  mkdir "$outdir", 0755;

  do_simulation($outdir, $simnum, 0);
}

#
# Monitor the currently running simulation.
#
sub monitor_simulation
{
  my %env = get_foamkit_env();

  if (!is_sim_running())
  {
    print "No simulation running!\n";
    return 0;
  }

  my $outdir = get_last_sim();
  run_command("bash $env{CASE_DIR}/scripts/monitor/Allrun $outdir", $env{CASE_DIR});
  return 1;
}

#
# End a currently running simulation.
#
sub end_simulation
{
  my %env = get_foamkit_env();

  if (!is_sim_running())
  {
    print "No simulation running!\n";
    return 0;
  }

  run_command("bash $env{CASE_DIR}/scripts/sim/Allend", $env{CASE_DIR});
  return 1;
}

#
# Continues the last run simulation.
#
sub continue_simulation
{
  do_simulation(get_last_sim(), get_last_sim_number(), 1);
}

#
# Helper for simulation.
#
sub do_simulation
{
  my ($outdir, $simnum, $continue) = @_;

  my %env = get_foamkit_env();

  # Make sure nothing is running right now
  if (is_sim_running())
  {
    print STDERR "There is already something running! If you've killed the process manually, remove the simulation_running line in foamkit.dat and try again.\n";
    return 0;
  }

  # Save state
  add_setup_data(("simulation_running" => 1, "last_simulation" => "$outdir"));

  my $logfile;

  # All output should go both to the screen and to a file
  if ($continue)
  {
    open $logfile, ">>", "$outdir/sim.txt";
    print $logfile, "\n\n";
    log_text($logfile, "CONTINUING\n");
    log_text($logfile, "==========\n\n");
  }
  else
  {
    open $logfile, ">", "$outdir/sim.txt";
    log_text($logfile, "RUNNING SIMULATION\n");
    log_text($logfile, "==================\n\n");
  }

  my $starttime = time;

  log_text($logfile, "Sim number:       $simnum\n");
  log_text($logfile, "Start time:       " . get_timestamp(1) . "\n");
  log_text($logfile, "Output directory: $outdir\n");
  log_text($logfile, "\n");

  # Do simulation: there should be an Allrun script in the sim directory
  run_command("bash $env{CASE_DIR}/scripts/sim/Allrun $outdir $continue", $env{CASE_DIR}, $logfile);

  my $endtime = time;
  my $duration = $endtime - $starttime;

  log_text($logfile, "\nFinish time:      " . get_timestamp(1) . "\n");
  log_text($logfile, "Duration:         " . format_timespan($duration) . "\n");

  close $logfile;

  add_setup_data(("simulation_running" => 0));

  return 1;
}

#
# Returns 1 if a simulation is running, 0 otherwise.
#
sub is_sim_running
{
  my %setup_data = get_setup_data();
  return (defined $setup_data{"simulation_running"} && $setup_data{"simulation_running"} == 1);
}

#
# Returns the directory of the last simulation done.
#
sub get_last_sim
{
  my %setup_data = get_setup_data();
  return "" unless defined $setup_data{"last_simulation"};
  return $setup_data{"last_simulation"};
}

#
# Returns the number of the last simulation done.
#
sub get_last_sim_number
{
  my $lastsim = get_last_sim();
  $lastsim =~ s:^.*/sim(\d+)_\d+_\d+$:$1:;
  return $lastsim;
}

#
# Returns the next available simulation number. e.g. if last simulation was
# 23 (as in, it was in the directory sim23_*), this one is 24 and uses the
# directory sim24_xxxxxx_xxxxxx.
#
sub get_sim_number
{
  my %env = get_foamkit_env();

  my $simdir = $env{SIM_DIR};

  # Add all simulation numbers to a hash
  my %simnums = ();
  my @dirs = read_files_in_dir($simdir, 0); # 0 = not recursive

  foreach (@dirs)
  {
    s:^$simdir/::;
    next unless /^sim(\d+)/;
    $simnums{$1} = 1;
  }

  return 1 if (scalar keys %simnums == 0);

  # Find the first unused sim number
  return max(keys %simnums) + 1;
}

1;

