```
                               .
                     oec :    @88>
                    @88888    %8P      .u    .
                    8"*88%     .     .d88B :@8c       .u
                    8b.      .@88u  ="8888f8888r   ud8888.
                   u888888> ''888E`   4888>'88"  :888'8888.
                    8888R     888E    4888> '    d888 '88%"
                    8888P     888E    4888>      8888.+"
                    *888>     888E   .d888L .+   8888L
                    4888      888&   ^"8888*"    '8888c. .+
                    '888      R888"     "Y"       "88888%
                     88R       ""                   "YP'
                     88>
                     48
                     '8
```

Fire is a parallelized ssh utility for executing remote commands on servers,
including file transfers and sudo commands.  It's very basic and will probably
piss you off!  It currently only runs under Ruby 1.8 because it was written
years ago and was never updated to use the newer threading in Ruby 1.9/2.0.

Usage
-----
```
usage: fire [options] CMD
    -f, --file FILE           File containing hosts, one per line
    -c, --command CMD         Command(s) to execute on each host
    -s, --scp FILE,...        File(s) to scp to each host before running CMD
    -v, --verbose             Show CMD output (and other information)
    -j, --jobs NUM            Number of simultaneous threads to spawn
    -u, -l, --user USER       User to ssh as (defaults to $USER)
    -i, --identity FILE       RSA key to use
    -P, --password            Prompt for user password
        --no-password         Don't use passwords at all
        --no-pubkey           Don't try pubkey authentication
    -k, --kinit               Prompt for user password using kinit(1)
    -d, --debug               Print debugging information
        --no-color            Your life is boring
    -h, --help                This useless garbage
```

Examples
--------
```
$ fire --file hosts.txt --command 'ip a s eth0' --verbose
```

```
$ fire -f hosts.txt --command 'sudo service ntp restart' -v
```

```
$ grep db hosts.txt | fire 'sudo iptables -L -n'
```

Ruby 1.8.7 on Arch Linux
------------------------
```
# meat -d ruby-install-git
# meat -d chruby
```
```
# ruby-install ruby 1.8.7
# source /usr/share/chruby/chruby.sh
# chruby ruby-1.8.7
```
