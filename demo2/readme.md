### Recording SSH sessions
There may be times you want to keep an exact record of what was done when somebody, possibly yourself, accesses your server. Maybe you have a consultant (like myself) helping to fix a problem or set up a new service, maybe you have a friend who needs to "just check something" for you, or maybe you aren't comfortable with a command line and want to keep a log of what you're doing on a server... whatever the reason, there are times you need to keep a copy of what happens over an SSH connection.

There are actually two different applications of recording SSH sessions- one involves the client keeping a log, and the other involves the server keeping a log. Both applications will be discussed below.

And the best part is, if you're using something other than M$-Windows, you probably already have all of the software you need in order to make this happen.

### Logging sessions from the SSH client
As a consultant, I use this quite a bit- in fact I normally keep a full transcript of all of my SSH sessions whenever I work on a client's machine, so I can show them exactly what I did (or didn't do) if there are any questions later on. And sometimes a client wants to see the full transcript, so they can learn how I do the things I do. It's nice to be able to provide them with that transcript.

The "secret" of logging from the client is to use a standard but little-used unix utility called "tee". It's a very simple program- anything it receives on its "standard input" channel, it writes out to a file, AND writes it to its "standard output" channel. It can be configured to append to a file rather than overwriting it, and some versions can write to more than one file at the same time.

Here's an example of how it works. If you would normally access the remote server using a command like this...
```
$ ssh -p 12345 userid@server
```
... then to record that session, you would use a command like this:

```
$ ssh -p 12345 userid@server | tee -a logfile
```

That's really all there is to it. The "-a" option for tee will make it add the log to the end of the existing file, if it already exists- if you don't want or need that behaviour, you can remove the "-a" option.

To make my own life easier, I have written a perl script called logssh. I can call it with the same parameters I normally use for an ssh command (i.e. I can type "logssh -p 12345 root@server.domain.xyz") and it will create a log of the session, in a directory which is hard-coded into the logssh script. It can also show the actual "ssh|tee" command pipeline (if you want to see it- at first I did, but now I don't bother anymore.)

```
File:	logssh
Size:	2,746 bytes
Date:	2008-08-06 22:01:33 +0000
MD5:	dee919ec50bce8c8dcf54269b5eb6f2d
SHA-1:	47fc6dbf713e8987ecc94b108f0e2f2c30e7fee7
RIPEMD-160:	1765243df980ea39c5825dab3fa2117536fd5812
PGP Signature:	logssh.asc
```

If you plan to use the script, make sure to check and fix all of the values in the configuration section at the top of the script, before trying to use it.

### Logging sessions on an SSH server
This is a bit more complicated. It also uses a fairly standard unix utility, "script", to create the log files, but it only works if the user accesses the machine using SSH, and if they authenticate using a key (as opposed to a password.)

Assuming all of your authorized users have keys and know how to use them (see this page for more information about how to set up and use keys for authentication), the idea is to attached a "forced command" to each user's key, so that when they connect, they run a specific script instead of the command they're asking for (or instead of just opening a shell session.) The trick is to write that script in such a way that it sets up the log file, but still allows them to access their shell, or run their command, without interfering with the session.

I wrote a script to do this on one of my clients' servers last year. I just looked at it again, and added some extra logic to deal with the new "internal-sftp" service in OpenSSH version 5, which allows you to chroot a user into a specific directory. There is no way to combine the chroot functionality with this command logging, but the script executes the old "sftp-server" binary so at least the user has a working SFTP session, even if they're not chroot'ed.

Installing the log-session script
```
File:	log-session
Size:	3,258 bytes
Date:	2008-08-07 03:40:58 +0000
MD5:	4d54b916b5ac43962da6b3e7073c9412
SHA-1:	7c59e0edb77c82622b47f020e545b05eb3a8bfe0
RIPEMD-160:	46d260668dc9763f011b1c7cff5d735a52101a0f
PGP Signature:	log-session.asc
```
Setting it up can be a bit tricky if you aren't used to dealing with SSH keys and forced commands. Here's an example showing how to set it up on a server. First download the script- I keep it in /usr/local/sbin so it can be used system-wide.

```
# cd /usr/local/sbin
# wget http://www.jms1.net/log-session
...

Find out where the sftp-server binary is located.

# grep sftp /etc/ssh/sshd_config Your sshd_config file may be in a different directory.
#Subsystem     sftp    /usr/libexec/openssh/sftp-server
Subsystem      sftp    internal-sftp

Put that value into the script.

# nano log-session
Use whatever text editor you like. Find this line (near the top) and set the variable to point to your sftp-server binary.
SFTP_SERVER=/usr/libexec/openssh/sftp-server

# chmod 755 log-session
```
### Add the forced command to each user's key
For each user whose SSH sessions you wish to record, you need to edit the user's ".ssh/authorized_keys" file. Find the line which contains their public key, and add a forced command to the beginning of the line which will make sshd run that script instead of whatever command they may have wanted to run. Be careful, some text editors may try to wrap the lines for you (the keys are very long.) DO NOT allow the editor to do this (or at least make sure you fix the damage before saving the file.)
```
# cd ~user/.ssh
# nano authorized_keys
Again, use whatever text editor you like. Find the line for their key, which will probably look like...
    ssh-dss AAAAB3NzaC1kc3MAAAEBAMKr1HxJzOWRQCm16Sf...
Add the forced command to the beginning of this line. The result should look like this...
    command="/usr/local/sbin/log-session" ssh-dss AAAAB3NzaC1kc3MAAAEBAMKr1HxJzOWRQCm16Sf...
```
After this is done, any time somebody connects to the server and uses that key to authenticate as that user, sshd will run the log-session script instead of whatever command they were trying to run. Of course, the script will run their original command- but it will log the session (unless they're doing an SFTP session, which I guess you could log, but since it's a binary protocol there's probably not much use in doing so. If you want to do this, directions can be found within the script itself.)

Diable password authentication
Of course, in order for this to work, the user MUST authenticate with that key. The easiest way to ensure this happens is to configure sshd so it doesn't accept passwords as an authentication method. You can do this in your sshd_config file by adding (or editing) this line:
```
PasswordAuthentication no
```
After making this change, restart sshd.

Note that this is a GLOBAL change, it will prevent ALL users from being able to authenticate using passwords- not just the users for whom you set up session logging. You should ensure that all authorized users have uploaded and installed their keys on the server, and that the keys are working before you make this change (otherwise you may be locking the users out of the system, thereby creating extra headaches for yourself.)


### Article From 
https://jms1.net/ssh-record.shtml
https://unix.stackexchange.com/questions/25639/how-to-automatically-record-all-your-terminal-sessions-with-script-utility


