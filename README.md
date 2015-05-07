Microsoft SQL Server ODBC Driver 1.0 for Linux Fixed Install Scripts
======================================================================

I named this repository in hopes that SEO would help it out a bit. One
 of my most popular posts on my blog is a how to detailing the steps 
needed for installing the Microsoft SQL Server ODBC Driver for linux 
on Ubuntu. Why is an install tutorial/how-to necessary? Because 
Microsoft released some half-baked install scripts.

The shell scripts they include contain the Microsoft Copyright, so I'm
 not sure of the license - which is why I didn't choose one for this 
repository - I just want the changes I made to be available to those 
that need them.

If you're seeing this Microsoft - please feel free to use any of this 
in your own distributions. It's painful to see half-baked install 
scripts when so little work is necessary to support so much more of 
your audience.

These are just some adjusted scripts to work on Debian/Ubuntu servers.
These are tested working on Ubuntu 12.04 and 14.04 LTS - and they're supposed to
 work out of the box on Red Hat Enterprise Linux 6 though I do not 
have access to an actual Red Hat Enterprise Linux 6 system so I've not 
100% tested their stated functionality. Running on
[dash](http://en.wikipedia.org/wiki/Debian_Almquist_shell) the hashbang
 needed to change to bash in order to support the array syntax used.
 
`install_dm.sh` is adjusted to pull [unixODBC](http://www.unixodbc.org/)
 version 2.3.2 from the web. Once the driver is installed, don't forget to enable Multiple Active Result-sets (MARS) in your ODBC connection as that's a great feature that this driver provides. `MARS_Connection = Yes`


##Usage

###unixODBC Driver Manager Install - build_dm.sh

```
$ sudo ./build_dm.sh --libdir=/usr/lib/x86_64-linux-gnu
```

You can also pass a path to where you've placed a gzipped tarball of 
unixODBC (including newer versions) using the `--download-url` parameter:

```
$ sudo ./build_dm.sh --download-url=file:///home/MYUSER/unixODBC-2.3.2.tar.gz --libdir=/usr/lib/x86_64-linux-gnu
```

###SQL Server ODBC Driver Installer - install.sh

For the driver installer - `install.sh` - `install`, `verify`, `--force`, and `--help`
 are available parameters:

```
$ sudo ./install.sh install
```

You can use verify to check the status of an existing installation:

```
$ sudo ./install.sh verify
```
