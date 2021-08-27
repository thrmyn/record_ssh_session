#! /bin/bash

# Check that the SSH client did not supply a command
if [[ -z $SSH_ORIGINAL_COMMAND ]]; then

  # The format of log files is /work/bastion/YYYY-MM-DD_HH-MM-SS_user
  LOG_FILE="`date --date="today" "+%Y-%m-%d_%H-%M-%S"`_`whoami`"
  mkdir -p "/work/bastion/log/`whoami`"
  LOG_DIR="/work/bastion/log/`whoami`/"

  # Print a welcome message

  echo "AUDIT KEY: $LOG_FILE"
  cat /work/bastion/welcome.txt


  # I suffix the log file name with a random string. I explain why
  # later on.
  SUFFIX=`mktemp -u _XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

  # Wrap an interactive shell into "script" to record the SSH session
 # script -qf -c "exec $SSH_ORIGINAL_COMMAND" --timing=$LOG_DIR$LOG_FILE$SUFFIX.time $LOG_DIR$LOG_FILE$SUFFIX.data
  script -qf --timing=$LOG_DIR$LOG_FILE$SUFFIX.time $LOG_DIR$LOG_FILE$SUFFIX.data

else

  # The "script" program could be circumvented with some commands
  # (e.g. bash, nc). Therefore, I intentionally prevent users
  # from supplying commands.

  echo "This bastion supports interactive sessions only. Do not supply a command"
  exit 1

fi
