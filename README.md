# termcapit

Usage:
  termcapit.sh [-h] [-d] [-t <termcap>] <update>

Updates termacp file with entries from update avoiding duplicates. If termcap
file gets changed the original termcap file is backed like this:
  /etc/termcap -> /etc/termcap.2017-07-28-11-47-19.backup

Options:
  h - Print usage and exit
  t - Path to termcap file, if not specified defaults to /etc/termcap
  d - Delete entries featured in the update file from the termcap file

