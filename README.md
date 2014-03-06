Members Area
============

[![Build Status](https://travis-ci.org/benjie/members-area.png?branch=master)](https://travis-ci.org/benjie/members-area)

This is a free and open source Members Area specifically targeted at
Makerspaces/Hackspaces/Hackerspaces though also suitable for other
community groups.

It's a ground-up rewrite of the original [So Make It][] Members Area.

Project status
--------------

Work in progress, getting there.

Getting started - Heroku
------------------------

Heroku instructions coming soon...

Getting started - development
-----------------------------

Install CoffeeScript and the members-area software globally:

```
npm install -g coffee-script members-area
```

Then create a new folder and initialise a new members are inside it:

```
mkdir myarea
cd myarea
members quickstart
```

You can then run the server:

```
coffee index.coffee
```

You'll probably want to set up a [mailgun][] (or similar) account so
Nodemailer can send the registration emails for further users you
register without them ending up in spam. Then in Core Settings, set:

- From address: `Your Name <you@yourdomain>`
- Service: `mailgun`
- Username: `postmaster@yourdomain`
- Password: `PasswordFromMailgun`

Contributing
------------

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
