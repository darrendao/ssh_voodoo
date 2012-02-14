# ssh_voodoo
ssh_voodo is a Ruby script to help with the task of running commands on remote machines via ssh. It allows you to run commands remotely in parallel and helps cache your password (including sudo) so you don't have to keep on entering your password. There's also an option to use ssh key.

## Installation
It&apos;s hosted on rubygems.org

    sudo gem install ssh_voodoo

## Usage

```
   ssh_voodoo -h
   Usage: ssh_voodoo [options]
     -s, --servers=SERVERS    Servers to apply the actions to
         --debug              Print lots of messages
         --use-ssh-key [FILE] Use ssh key instead of password
     -c, --command=STRING     What command to run on the remote server
         --username=USERNAME  What username to use for connecting to remote servers
         --dw=INTEGER         Number of workers for parallel ssh connections
         --connectiontimeout=INTEGER
                              Connection timeout
     -h, --help               Show this message
```
