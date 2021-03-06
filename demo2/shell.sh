#!/bin/sh
#
# log-session
# John Simpson <jms1@jms1.net> 2008-08-06
#
###############################################################################
#
# Copyright (C) 2008 John Simpson.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 3, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################
#
# configuration

# copy this value from the "Subsystem sftp" line in your sshd_config file
SFTP_SERVER=/usr/libexec/openssh/sftp-server

###############################################################################
###############################################################################
###############################################################################

NOW=`date +%Y-%m-%d.%H%M%S`
IP=`echo $SSH_CLIENT | sed 's/ .*//'`
LOGFILE=/root/.ssh/log.$NOW.$IP

# if you want to log the initial contents of the environment received from
# sshd, un-comment these lines.
#
# env | sort >> $LOGFILE
# echo "========================================" >> $LOGFILE

# the "internal-sftp" service is new as of openssh 5.0. it works like
# the sftp server logic is built into sshd, and as such it's capable of
# chroot'ing users into their home directories.
# there's no way to "redirect" execution back into it, so the best we
# can do is exec the old sftp-server instead, which will give the user a
# working sftp session, but won't chroot them into their home directory.

if [ "${SSH_ORIGINAL_COMMAND:-}" = "internal-sftp" ]
then
	echo "substituting $SFTP_SERVER for internal SFTP service" >> $LOGFILE
	echo "========================================" >> $LOGFILE
	exec $SFTP_SERVER

# if they're requesting the sftp server, this is an sftp command.
# logging the traffic wouldn't make much sense, it's a binary protocol...
# although if you really want to log the raw data, comment out this block
# and let execution fall through to the next block.

elif [ "${SSH_ORIGINAL_COMMAND:-}" = "$SFTP_SERVER" ]
then
	echo starting SFTP service >> $LOGFILE
	echo ======================================== >> $LOGFILE
	exec $SFTP_SERVER

# if the user asked for a specific command, run that command
# but log the traffic going into and out of it.

elif [ -n "${SSH_ORIGINAL_COMMAND:-}" ]
then
	echo executing $SSH_ORIGINAL_COMMAND >> $LOGFILE
	echo ======================================== >> $LOGFILE
	exec script -a -f -q -c "$SSH_ORIGINAL_COMMAND" $LOGFILE

# no command was requested, user wants an interactive shell.
# of course, log the traffic going in and out of it.

else
	echo starting interactive shell session >> $LOGFILE
	echo ======================================== >> $LOGFILE
	exec script -a -f -q $LOGFILE
fi

# if we get to this point, an "exec" failed somewhere.

echo exec failed, rv=$?
exit 1
