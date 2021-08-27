#! /bin/bash

mkdir -p /work/tmp

# The file will log user changes
LOG_FILE="/work/bastion/users_changelog.txt"

# The function returns the user name from the public key file name.
# Example: public-keys/sshuser.pub => sshuser
get_user_name () {
  echo "$1" | sed -e 's/.*\///g' | sed -e 's/\.pub//g'
}

ls /work/pub_keys | sed -e 'y/\t/\n/' > /work/tmp/keys_retrieved

while read line; do
  USER_NAME="`get_user_name "$line"`"

  # Make sure the user name is alphanumeric
  if [[ "$USER_NAME" =~ ^[a-z]*_[a-z0-9]*?$ ]]; then

    # Create a user account if it does not already exist
    cut -d: -f1 /etc/passwd | grep -qx $USER_NAME

    if [ $? -eq 1 ]; then
      /usr/sbin/adduser $USER_NAME && \
      mkdir -m 700 /home/$USER_NAME/.ssh && \
      chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh && \
      echo "$line" >> /work/tmp/keys_installed && \
      echo "`date --date="today" "+%Y-%m-%d %H-%M-%S"`: Creating user account for $USER_NAME ($line)" >> $LOG_FILE
    fi

    # Copy the public key from S3, if a user account was created
    # from this key
    if [ -f /work/tmp/keys_installed ]; then
      grep -qx "$line" /work/tmp/keys_installed
      if [ $? -eq 0 ]; then
        cp /work/pub_keys/$line /home/$USER_NAME/.ssh/authorized_keys
        chmod 600 /home/$USER_NAME/.ssh/authorized_keys
        chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh/authorized_keys
      fi
    fi

  fi
done < /work/tmp/keys_retrieved

# Remove user accounts whose public key was deleted from S3
if [ -f /work/tmp/keys_installed ]; then
  sort -uo /work/tmp/keys_installed /work/tmp/keys_installed
  sort -uo /work/tmp/keys_retrieved /work/tmp/keys_retrieved
  comm -13 /work/tmp/keys_retrieved /work/tmp/keys_installed | sed "s/\t//g" > /work/tmp/keys_to_remove
  while read line; do
    USER_NAME="`get_user_name "$line"`"
    echo "`date --date="today" "+%Y-%m-%d %H-%M-%S"`: Removing user account for $USER_NAME ($line)" >> $LOG_FILE
    /usr/sbin/userdel -r -f $USER_NAME
  done < /work/tmp/keys_to_remove
  comm -3 /work/tmp/keys_installed /work/tmp/keys_to_remove | sed "s/\t//g" > ~/tmp && mv ~/tmp /work/tmp/keys_installed
fi
