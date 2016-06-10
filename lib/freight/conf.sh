# Freight configuration.

# Default directories for the Freight library and Freight cache.  Your
# web server's document root should be `$VARCACHE`.
VARLIB="/var/lib/freight"
VARCACHE="/var/cache/freight"

# Default architectures.
# shellcheck disable=SC2034
APT_ARCHS="i386 amd64"
YUM_ARCHS="i386 x86_64"

# Default `Origin` and `Label` fields for `Release` files.
# shellcheck disable=SC2034
ORIGIN="Freight"
# shellcheck disable=SC2034
LABEL="Freight"

# Base URL to use in XML href tags
SITE_URL=''

# Cache the control files after each run (on), or regenerate them every
# time (off).
# shellcheck disable=SC2034
CACHE="off"

# Whether to follow symbolic links in `$VARLIB` to produce extra components
# in the cache directory (on) or not (off).
# shellcheck disable=SC2034
SYMLINKS="off"

# Source all existing configuration files from lowest- to highest-priority.
PREFIX="$(dirname "$(dirname "$0")")"
if [ "$PREFIX" = "/usr" ]
then [ -f "/etc/freight.conf" ] && . "/etc/freight.conf"
else [ -f "$PREFIX/etc/freight.conf" ] && . "$PREFIX/etc/freight.conf"
fi
[ -f "$HOME/.freight.conf" ] && . "$HOME/.freight.conf"
DIRNAME="$PWD"
while true
do
    [ -f "$DIRNAME/etc/freight.conf" ] && . "$DIRNAME/etc/freight.conf" && break
    [ -f "$DIRNAME/.freight.conf" ] && . "$DIRNAME/.freight.conf" && break
    [ "$DIRNAME" = "/" ] && break
    DIRNAME="$(dirname "$DIRNAME")"
done
[ "$FREIGHT_CONF" -a -f "$FREIGHT_CONF" ] && . "$FREIGHT_CONF"
if [ "$CONF" ]
then
    if [ -f "$CONF" ]
    then . "$CONF"
    else
        echo "# [freight] $CONF does not exist" >&2
        exit 1
    fi
fi

# Normalize directory names.
VARLIB=${VARLIB%%/}
VARCACHE=${VARCACHE%%/}

# vim: et:ts=4:sw=4
