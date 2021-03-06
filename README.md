# Apocalypse Client

Apocalypse Client is a ruby gem that can be installed on a remote
server.

## Installation

Apocalypse Client currently focusses on Debian/Ubuntu systems only.

There is only one dependency to the operating system, namely the
`sysstat` package. This package is used to gather information about disk
utilisation and performance.

    sudo apt-get install sysstat

Next install the ruby gem.

    sudo gem install apocalypse-client

once installed run the install|now command
  apocalypse-client now
    
This will send metrics data every minute to your Apocalypse server. If
you require different intervals, refer to `man 5 crontab` for details on
how to schedule reporting.

If an error occurs cron will try to notify you by email. This depends on
how your systems cron is configured.

## Choosing a proper hostid

Choosing a proper hostid is important, because it can be arbitrarily
chosen. There are several options:

 * Use the format `appname-role-number`. E.g. `ariejannet-db-01` or
   `reddis-memcached-42`.
 * IP Address of the server, this guarantees some level of uniqueness

Note: at this time, there is not convention for picking hostids.
However, the first method is likely to become the convention and will
allow logical grouping of servers by role and application.

## Authors

 * Ariejan de Vroom <ariejan@ariejan.net>
 * Kabisa ICT - http://kabisa.nl

## License

    Copyright (c) 2011 Ariejan de Vroom
    
    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:
    
    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    
