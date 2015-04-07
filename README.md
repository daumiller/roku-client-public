# Plex/Roku

The official Plex client for the Roku.

## Installation

If you're just trying to install the channel normally, you don't need to be
here. You can install the released version of the channel using the Roku
Channel Store. You can also install various prerelease or private builds
using install links provided by the dev team, and a Plex Pass preview
build channel that you can install by using the private channel code
`plexpass`.

Ok, if you're still reading then you presumably want to install from source
and hopefully make some useful changes. You don't need to download or install
anything from Roku, but you should take a look at Roku's
[developer site](http://www.roku.com/developer). In addition to the downloadable
PDF documentation, you can [browse the docs online](http://sdkdocs.roku.com/).
Roku's docs are well above average.

### Dev Mode

Before you can actually install Roku channels from source, you need to make
sure your Roku is in "dev" mode:

1. Using the Roku remote, press `Home-Home-Home-Up-Up-Right-Left-Right-Left-Right`
2. Choose to Enable the Installer

You only need to do this once, it will remain in dev mode. If you ever want to
exit dev mode you can use the same remote sequence.

If you're prompted to set a password, using `plex` will save you the
hassle of setting an additional environment variable in order to use
various utilities in the Makefile.

### Building and Installing Locally

There's a Makefile that should take care of everything for you. You just need
to set an environment variable with the IP address of your Roku. Assuming
you're in a unix-like environment:

1. `export ROKU_DEV_TARGET=192.168.1.2` (substituting your IP address...)
2. `cd Plex2d`
3. `make dev install`

There are some additional targets for making different flavors of the
build for our various channels.

- `make dev` - The default, a PlexDev package, should never be uploaded to
  the store.
- `make ninja` - A PlexNinja package, for uploading to the private channel
  used by ninjas. This channel should never actually be published, we give
  the ninjas the temporary install code.
- `make pass` - A PlexPass package, for uploading to the Plex Pass private
  preview channel.
- `make public` - A Plex package, for uploading to the public channel.

If you have httpie installed, you can also create and download a package
instead of having to use the application packager in a browser. The 
targets above can be used in addition to `pkg`, so `make public pkg` will
create a package and download it to `../packages/Plex_P{md5sum}.pkg`.

One other nicety is the ability to take a screenshot using `make screenshot`.
It will save an image at `roku_screenshot-{timestamp}.jpg` and symlink the
most recent screenshot at `roku_screenshot.jpg`.

**Note:** Roku requires HTTP authentication for all installation and
packaging utilities. This is handled (although curl and roku don't always
play nicely), but you may need to set environment variables for
`ROKU_DEV_USERNAME` and `ROKU_DEV_PASSWORD`, which default to `rokudev`
and `plex` respectively.

### Publishing

The Makefile also has some targets that automate publishing packages to
Roku's channel store. All of these targets require [httpie](http://httpie.org)
to be installed locally and executable as `http`.

- `make pkg` - Installs a package onto the local Roku and downloads it
  in `.pkg` format from the application packager.
- `make upload` - Uploads a package to the Roku store **without** publishing
  it. The installation code will be echoed so that it can be tested before
  publishing. This target executes `pkg` as a dependency, so a new package
  will always be created before uploading.
- `make publish` - Publishes a pending package in the Roku store. This
  target does **not** depend on `upload`, since you will often upload,
  then test, then publish, as discrete steps.

These targets all take the usual phony targets to build a particular
version of the channel. So to upload a Ninja build you'd use
`make ninja upload` and to upload a Plex Pass build you'd use
`make pass upload`. These targets also require additional credentials
for packaging and uploading. They should be prompted for if not
provided, but you can also set environment variables if you'd like to
automate the process further. The environment variables are:

- `ROKU_PKG_PASSWORD` - The password used for the local application packager.
- `ROKU_PORTAL_USERNAME` - The email address used to login to owner.roku.com
- `ROKU_PORTAL_PASSWORD` - The password used to login to owner.roku.com.
- `ROKU_PKG_VERSION` - The version to assign to an uploaded package. This
  is currently defaulted to 1.1 during our preview period since we can't
  use numbers less than 1.0. Once we release, we can probably read this
  from the manifest.

Here are some common specific examples:

#### Upload Ninja build

    make ninja upload

(Note that we haven't been publishing ninja builds, only uploading!)

#### Upload Plex Pass build

    make pass upload

#### Publish Plex Pass build

    make pass publish

#### Upload Public build

    make public upload

### Debugging

The Roku doesn't have logging per se, but dev channels are able to write
messages to a console that you can tail using telnet. It's as simple as

    telnet $ROKU_DEV_TARGET 8085

While connected via telnet, `Ctrl-c` will stop the dev channel and open
a debugger. It's not an especially rich debugger, but you can print
variables and step through execution. Type `help` to see a list of
commands or consult Roku's documentation. To disconnect the telnet
session, you can use `Ctrl-]` and then type `quit`.
