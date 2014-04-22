Members Area
============

[![Build Status](https://travis-ci.org/members-area/members-area.png?branch=master)](https://travis-ci.org/members-area/members-area)

This is a free and open source Members Area specifically targeted at
Makerspaces/Hackspaces/Hackerspaces though also suitable for other
community groups.

It's a ground-up rewrite of the original [So Make It][] Members Area.

Project status
--------------

Work in progress, getting there.

Getting started
---------------

Install members-area software globally:

```
npm install -g members-area
```

Then create a new folder and initialise a new members are inside it:

```
mkdir myarea
cd myarea
members quickstart
```

After a period of time installing the various dependencies, setting up a
SQLite database, installing the default plugins, etc the server will be
up and running on [localhost:1337](http://127.0.0.1:1337/).

In future you can run the members area with `members run` or `npm start`
or, if you have installed CoffeeScript globally, `coffee index.coffee`.

You'll probably want to set up a [mailgun][] (or similar) account so
Nodemailer can send the registration emails for further users you
register without them ending up in spam. Then in Core Settings, set:

- From address: `Your Name <you@yourdomain>`
- Service: `mailgun`
- Username: `postmaster@yourdomain`
- Password: `PasswordFromMailgun`

Contributing
------------

For a really fast way to get up and running with developing for the
members area, check out the [bootstrap.sh](bootstrap.sh) file - simply
download it somewhere and then run it. It runs under bash -
contributions of a Windows equivalent welcome...

Once the script finishes running you'll have a folder `MembersArea`
containing a checkout of the members-area itself and a number of
plugins. There'll also be a folder called `instance` that contains a
members-area instance since the members-area itself is just a node
module and is not intended to run on it's own. You'll want to run
`./watch.sh` inside instance to monitor all the various modules for
changes.

I've designed the members area to have a plugin architecture allowing
for easy expansion. In fact many of the features that could have been
core are implemented as plugins. You can easily contribute to the
ecosystem by making a plugin to expand the functionality of the members
area.

I want to keep the core pretty tight, simple and reliable; improvements
to performance, security and other fixes are welcome, as are additional
plugin hooks if well thought out, but if you plan on adding more
functionality to core it may be worth having a chat first :)

Bootstrap
---------

I'm no designer, so I use [Bootstrap 2.3.2][], if you wish to
contribute, the documentation can be found there.

[Bootstrap 2.3.2]: http://getbootstrap.com/2.3.2/
[So Make It]: http://www.somakeit.org.uk/
[mailgun]: https://mailgun.com
