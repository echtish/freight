TTY="$(tty -s && echo "1" || :)"
RPM_QUERY_FORMAT="\
Name        : %{NAME}\n\
%|EPOCH?{Epoch       : %{EPOCH}\n}|\
Version     : %{VERSION}\n\
Release     : %{RELEASE}\n\
Architecture: %{ARCH}\n\
Install Date: %|INSTALLTIME?{%{INSTALLTIME:date}}:{(not installed)}|\n\
Group       : %{GROUP}\n\
Size        : %{LONGSIZE}\n\
Package Size: %{SIZE}\n\
Archive Size: %{ARCHIVESIZE}\n\
Build Time  : %{BUILDTIME}\n\
%|LICENSE?{License     : %{LICENSE}}|\n\
Signature   : %|DSAHEADER?{%{DSAHEADER:pgpsig}}:{%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{%|SIGGPG?{%{SIGGPG:pgpsig}}:{%|SIGPGP?{%{SIGPGP:pgpsig}}:{(none)}|}|}|}|\n\
Source RPM  : %{SOURCERPM}\n\
Build Date  : %{BUILDTIME:date}\n\
Build Host  : %{BUILDHOST}\n\
Relocations : %|PREFIXES?{[%{PREFIXES} ]}:{(not relocatable)}|\n\
%|PACKAGER?{Packager    : %{PACKAGER}\n}|\
%|VENDOR?{Vendor      : %{VENDOR}\n}|\
%|URL?{URL         : %{URL}\n}|\
%|BUGURL?{Bug URL     : %{BUGURL}\n}|\
Provides    : [%{PROVIDENAME} %|PROVIDEFLAGS?{%{PROVIDEFLAGS:depflags} %{PROVIDEVERSION}}:{}|, ]\n\
Requires    : [%{REQUIRENAME} %|REQUIREFLAGS?{%{REQUIREFLAGS:depflags} %{REQUIREVERSION}}:{}|,]\n\
Conflicts   : [%{CONFLICTNAME} %|CONFLICTFLAGS?{%{CONFLICTFLAGS:depflags} %{CONFLICTVERSION}}:{}|,]\n\
Obsoletes   : [%{OBSOLETENAME} %|OBSOLETEFLAGS?{%{OBSOLETEFLAGS:depflags} %{OBSOLETEVERSION}}:{}|,]\n\
Summary     : %{SUMMARY}\n\
Description :\n%{DESCRIPTION}\n"

html_entities() {
	echo "$1" | sed -e 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g;s/"/\&quot;/g'
}

# Fetch the given field from the package's control file.
yum_info() {
	egrep -i "^$2[[:space:]]*:" "$1" | cut -d: -f2- | cut -c2-
}

# Print the package name from the given control file.
yum_binary_name() {
	yum_info "$1" Name
}

# Print the version from the given control file.
yum_binary_version() {
	VERSION="$(yum_info "$1" Version)"
	RELEASE="$(yum_info "$1" Release)"
	[ -n "$RELEASE" ] && echo "$VERSION-$RELEASE" || echo "$VERSION"
}

yum_binary_release() {
	yum_info "$1" Release
}

# Print the architecture from the given control file.
yum_binary_arch() {
	yum_info "$1" Architecture
}

# Print the source name from the given control file.
yum_binary_sourcename() {
	SOURCE="$(yum_info "$1" "Source RPM")"
	[ -z "$SOURCE" ] && SOURCE="$(yum_binary_name "$1")"
	echo "$SOURCE"
}

# Print the prefix the given control file should use in the pool.
yum_binary_prefix() {
	yum_prefix "$(yum_binary_sourcename "$1")"
}

yum_binary_summary() {
	yum_info "$1" Summary
}

# Print the Description field, which is the last line of
# RPM info cache file
yum_binary_description() {
	sed "1,/^Description[[:space:]]*:/d" "$1"
}

yum_binary_packager() {
	yum_info "$1" Packager
}

yum_binary_license() {
	yum_info "$1" License
}

yum_binary_vendor() {
	yum_info "$1" Vendor
}

yum_binary_url() {
	yum_info "$1" URL
}

yum_binary_group() {
	yum_info "$1" Group
}

yum_binary_provides() {
	yum_info "$1" Provides
}

yum_binary_conflicts() {
	yum_info "$1" Conflicts
}

yum_binary_requires() {
	yum_info "$1" Requires
}

yum_binary_obsoletes() {
	yum_info "$1" Obsoletes
}

yum_binary_buildhost() {
	yum_info "$1" "Build Host"
}

yum_binary_build_time() {
	yum_info "$1" "Build Time"
}

yum_binary_file_time() {
	yum_info "$1" "File Time"
}

yum_binary_archive_size() {
	yum_info "$1" "Archive Size"
}

yum_binary_pkg_size() {
	yum_info "$1" "Package Size"
}

# Extract RPM header byte range
yum_binary_pkg_header_range() {
	pkg=$1
	[ -f "$1" ] || return 1

	# rpm2cpio.sh, available in rpm.git
	leadsize=96
	o=`expr $leadsize + 8`
	set `od -j $o -N 8 -t u1 $pkg`
	il=`expr 256 \* \( 256 \* \( 256 \* $2 + $3 \) + $4 \) + $5`
	dl=`expr 256 \* \( 256 \* \( 256 \* $6 + $7 \) + $8 \) + $9`
	# echo "sig il: $il dl: $dl"

	sigsize=`expr 8 + 16 \* $il + $dl`
	o=`expr $o + $sigsize + \( 8 - \( $sigsize \% 8 \) \) \% 8 + 8`
	set `od -j $o -N 8 -t u1 $pkg`
	il=`expr 256 \* \( 256 \* \( 256 \* $2 + $3 \) + $4 \) + $5`
	dl=`expr 256 \* \( 256 \* \( 256 \* $6 + $7 \) + $8 \) + $9`
	# echo "hdr il: $il dl: $dl"

	hdrsize=`expr 8 + 16 \* $il + $dl`
	#o=`expr $o + $hdrsize`
	echo "$o-$hdrsize"
	#dd if=$pkg ibs=$o skip=1 2>/dev/null
}
yum_binary_pkg_header_start() {
	echo "$(yum_binary_pkg_header_range "$1")" | cut -d- -f1 -s
}
yum_binary_pkg_header_end() {
	echo "$(yum_binary_pkg_header_range "$1")" | cut -d- -f2 -s
}

# Print the name portion of a source package's pathname.
yum_source_name() {
	basename "$1" ".rpm" | cut -d_ -f1
}

# Print the version portion of a source package's pathname.
yum_source_version() {
	basename "$1" ".rpm" | cut -d- -f1
}

yum_source_release() {
	yum_source_version "$1" | cut -d- -f2
}
# Print the prefix for a package name.
yum_prefix() {
	[ "$(echo "$1" | cut -c1-3)" = "lib" ] && C=4 || C=1
	echo "$1" | cut -c-$C
}

# Print the checksum portion of the normal checksumming programs' output.
yum_md5() {
	md5sum "$1" | cut -d" " -f1
}
yum_sha1() {
	sha1sum "$1" | cut -d" " -f1
}
yum_sha256() {
	sha256sum "$1" | cut -d" " -f1
}

# Print the size of the given file.
yum_filesize() {
	stat -c%s "$1"
}
yum_filemtime() {
	stat -c%Y "$1"
}

yum_xml_header() {
	encoding="$(env | grep LANG | sed 's/^[^=]*//' | cut -d. -f2)"
	[ -z "$encoding" ] && encoding="UTF-8"
	echo "<?xml version=\"1.0\" encoding=\"$encoding\"?>"
}
yum_dist_arch_has_packages() {
	# $1: DIST
	# $2: ARCH
	pkgl="$DISTCACHE/$1/binary-$2/repodata/freight-pkglist"
	if [ ! -f "$pkgl" ]; then
		echo "0"
		return 0
	fi
	pkgl_count=$(wc -l "$pkgl" | cut -d' ' -f1)
	if [ $pkgl_count -gt 0 ]; then
		echo "$pkgl_count"
	else
		echo "0"
	fi
}
yum_entry_name() {
	echo "$1" | cut -d' ' -f1
}
yum_entry_flags() {
	flag=$(echo "$1" | cut -d' ' -f2 -s)
	case "$flag" in
		'=' ) echo 'EQ' ;;
		'<=') echo 'LE' ;;
		'>=') echo 'GE' ;;
		'>' ) echo 'GT' ;;
		'<' ) echo 'LT' ;;
		*) echo '' ;;
	esac
}
yum_entry_version() {
	echo "$1" | cut -d' ' -f3 -s | cut -d- -f1
}
yum_entry_epoch() {
	#FIXME: need to set properly, just 0 for now
	v="$(yum_entry_version "$1")"
	[ -n "$v" ] && echo '0' || :
}
yum_entry_release() {
	echo "$1" | cut -d' ' -f3 -s | cut -d- -f2- -s
}
yum_rpm_entry_xml() {
	local TAG="$1"
	local ENTRIES="$2"
	local SEP="$3"

	lines=$(
	{
		IFS=$SEP
		for e in $ENTRIES
		do
			e="$(echo "$e" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
			[ -n "$e" ] || continue
			name="$(yum_entry_name "$e")"
			flags="$(yum_entry_flags "$e")"
			epoch="$(yum_entry_epoch "$e")"
			version="$(yum_entry_version "$e")"
			release="$(yum_entry_release "$e")"
			x="<rpm:entry"
			[ -n "$name" ] && x="$x name=\"$name\""
			[ -n "$flags" ] && x="$x flags=\"$flags\""
			[ -n "$epoch" ] && x="$x epoch=\"$epoch\""
			[ -n "$version" ] && x="$x version=\"$version\""
			[ -n "$release" ] && x="$x release=\"$release\""
			echo "$x/>" 
		done 
		unset IFS	
	} | uniq)
	[ -n "$lines" ] && echo "<rpm:$TAG>\n$lines\n</rpm:$TAG>" || :
}

# See yum.packages.YumAvailablePackage._return_primary_files and
# yum.misc.re_primary_filename for details.
yum_rpm_is_dir_primary() {
	[ -n "$(echo "$1" | grep -o '^/etc/')" ] && return
	[ -n "$(echo "$1" | grep -o 'bin/')" ] && return
	return 1
}
yum_rpm_is_file_primary() {
	yum_rpm_is_dir_primary "$1" && return
	[ "$1" = "/usr/lib/sendmail" ] && return
	return 1
}
yum_filelist_name() {
	echo "$1" | cut -f1
}
yum_filelist_type() {
	type="$(echo "$1" | cut -f2- -s)"
	case "$type" in
		'directory' ) echo 'type="dir"' ;;
		*) echo '' ;;
	esac
}
yum_rpm_filelist_xml() {
	FILES="$1"
	SEP="$2"

	[ -n "$3" -a "$3" = 'primary' ] && PRIMARY=1 || PRIMARY=0

	lines=$(
	{
		IFS='
'
		for e in $FILES
		do
			e=$(echo "$e" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')
			[ -n "$e" ] || continue
			name="$(yum_filelist_name "$e")"
			type="$(yum_filelist_type "$e")"
			x="<file"
			[ -n "$type" ] && x="$x $type"
			x="${x}>${name}</file>"
			if [ $PRIMARY -eq 1 ]; then
				yum_rpm_is_file_primary "$name" && echo "$x"
			else
				echo "$x"
			fi
		done 
		unset IFS	
	} | uniq)
	echo "$lines"
}
yum_changelog_attrs() {
	author="$(html_entities "$(echo "$1" | sed 's/^\*[[:space:]]*[0-9]*[[:space:]]*//')")"
	date="$(echo "$1" | sed 's/^\*[[:space:]]*\([0-9]*\)[[:space:]]*.*$/\1/')"
	echo "author=\"$author\" date=\"$date\""
}
yum_changelog_entry() {
	type="$(echo "$1" | cut -f2- -s)"
	case "$type" in
		'directory' ) echo 'type="dir"' ;;
		*) echo '' ;;
	esac
}
yum_rpm_changelog_xml() {
	CHANGES="$1"

	lines=$(
	{
		IFS='
'
		change_header=''
		change_entries=''
		
		for c in $CHANGES
		do
			if [ -n "$(echo "$c" | grep -x '^\*.*$')" ]; then
				[ -z "$change_header" -a -z "$change_entries" ] || {
					# malformed changelog entry, drop it
					change_entries=''
					change_header=''
					continue
				}
				change_header="<changelog $(yum_changelog_attrs "$c")>"
			elif [ -n "$(echo "$c" | grep -x '^++freight-changelog-delim++$')" ]; then
				[ -n "$change_header" -a -n "$change_entries" ] || {
					# malformed changelog entry, drop it
					change_entries=''
					change_header=''
					continue
				}
				echo "$change_header$change_entries</changelog>"
				change_entries=''
				change_header=''
			elif [ -n "$(echo "$c" | grep -x '^.*[^[:space:]]\{1,\}.*$')" ]; then
				[ -n "$change_header" ] || {
					# malformed changelog entry, drop it
					change_entries=''
					change_header=''
					continue
				}
				if [ -z "$change_entries" ]; then
					change_entries="$(html_entities "$c")"
				else
					change_entries="${change_entries}\n$(html_entities "$c")"
				fi
			else
				# empty line, malformed changelog, skip it
				continue
			fi
		done 
		unset IFS	
	})
	echo "$lines"
}
yum_package_metadata_xml() {
	cat "$DISTCACHE/$COMP/binary-$ARCH/repodata/freight-pkglist" 2> /dev/null |
	while read PACKAGE 
	do
		PACKAGE="${PACKAGE##*/}"
		FILE="$DISTCACHE/.refs/$COMP/$PACKAGE"
		RPM_CACHE="$TMP/.rpm-info-cache/$DIST/$COMP/$PACKAGE"
		[ -d "$RPM_CACHE" ] || continue

		INFO="$RPM_CACHE/info"
		PKG_ID=$(cat "$RPM_CACHE/pkgid")
		FILE_LIST=$(cat "$RPM_CACHE/filelist")
		PKG_ARCH="$(yum_binary_arch "$INFO")"
		NAME="$(yum_binary_name "$INFO")"
		VERSION="$(yum_source_version "$(yum_binary_version "$INFO")")"
		RELEASE="$(yum_binary_release "$INFO")"
		SUMMARY="$(yum_binary_summary "$INFO")"
		DESCRIPTION="$(yum_binary_description "$INFO")"
		URL="$(yum_binary_url "$INFO")"
		LICENSE="$(yum_binary_license "$INFO")"
		VENDOR="$(yum_binary_vendor "$INFO")"
		GROUP="$(yum_binary_group "$INFO")"
		HEADER_START="$(yum_binary_pkg_header_start "$FILE")"
		HEADER_END="$(yum_binary_pkg_header_end "$FILE")"
		BUILDHOST="$(yum_binary_buildhost "$INFO")"
		PACKAGER="$(yum_binary_packager "$INFO")"
		PREFIX="$(yum_binary_prefix "$INFO")"
		SOURCE="$(yum_binary_sourcename "$INFO")"
		FILENAME="${NAME}-${VERSION##*:}-${RELEASE}.${PKG_ARCH}.rpm"
		HREF="/pool/$DIST/$COMP/$PREFIX/$SOURCE/$FILENAME"
		PKG_SIZE="$(yum_filesize "$FILE")"
		INSTALLED_SIZE="$(yum_binary_pkg_size "$INFO")"
		ARCHIVE_SIZE="$(yum_binary_archive_size "$INFO")"
		BUILD_TIME="$(yum_binary_build_time "$INFO")"
		FILE_TIME="$(yum_filemtime "$FILE")"
		CONFLICTS="$(yum_rpm_entry_xml "conflicts" "$(yum_binary_conflicts "$INFO")" "," )"
		PROVIDES="$(yum_rpm_entry_xml "provides" "$(yum_binary_provides "$INFO")" "," )"
		REQUIRES="$(yum_rpm_entry_xml "requires" "$(yum_binary_requires "$INFO")" "," )"
		OBSOLETES="$(yum_rpm_entry_xml "obsoletes" "$(yum_binary_obsoletes "$INFO")" "," )"
		PRIMARY_FILES="$(yum_rpm_filelist_xml "$FILE_LIST" "\t" "primary")"

		echo "<package type=\"rpm\">"
		echo "<name>$NAME</name>"
		echo "<arch>$PKG_ARCH</arch>"
		echo "<version epoch=\"0\" ver=\"$VERSION\" rel=\"$RELEASE\"/>" 
		echo "<checksum type=\"sha\" pkgid=\"YES\">$PKG_ID</checksum>"
		echo "<summary>$(html_entities "$SUMMARY")</summary>"
		echo "<description>$(html_entities "$DESCRIPTION")</description>"
		echo "<packager>$(html_entities "$PACKAGER")</packager>"
		echo "<url>$URL</url>"
		echo "<time file=\"$FILE_TIME\" build=\"$BUILD_TIME\"/>"
		echo "<size package=\"$PKG_SIZE\" installed=\"$INSTALLED_SIZE\" archive=\"$ARCHIVE_SIZE\"/>"
		if [ -n "$SITE_URL" ]; then
			echo "<location xml:base=\"$SITE_URL\" href=\"$HREF\"/>"
		else
			echo "<location href=\"$HREF\"/>"
		fi
		echo "<format>"
		echo "<rpm:license>$(html_entities "$LICENSE")</rpm:license>"
		echo "<rpm:vendor>$(html_entities "$VENDOR")</rpm:vendor>"
		echo "<rpm:group>$GROUP</rpm:group>"
		echo "<rpm:buildhost>$(html_entities "$BUILDHOST")</rpm:buildhost>"
		echo "<rpm:sourcerpm>$SOURCE</rpm:sourcerpm>"
		echo "<rpm:header-range start=\"$HEADER_START\" end=\"$HEADER_END\"/>"
		for i in PROVIDES CONFLICTS REQUIRES OBSOLETES PRIMARY_FILES; do
			[ -n "$(eval echo "\$$i")" ] && echo "$(eval "echo \"\$$i\"")"
		done
		echo "</format>"
		echo "</package>"
	done
}

yum_package_otherdata_xml() {
	cat "$DISTCACHE/$COMP/binary-$ARCH/repodata/freight-pkglist" 2> /dev/null |
	while read PACKAGE 
	do
		PACKAGE="${PACKAGE##*/}"
		FILE="$DISTCACHE/.refs/$COMP/$PACKAGE"
		RPM_CACHE="$TMP/.rpm-info-cache/$DIST/$COMP/$PACKAGE"
		[ -d "$RPM_CACHE" ] || continue

		INFO="$RPM_CACHE/info"
		PKG_ID=$(cat "$RPM_CACHE/pkgid")
		CHANGE_LIST=$(cat "$RPM_CACHE/changelog")
		PKG_ARCH="$(yum_binary_arch "$INFO")"
		NAME="$(yum_binary_name "$INFO")"
		VERSION="$(yum_source_version "$(yum_binary_version "$INFO")")"
		RELEASE="$(yum_binary_release "$INFO")"
		CHANGELOG="$(yum_rpm_changelog_xml "$CHANGE_LIST")"

		echo "<package id=\"$PKG_ID\" name=\"$NAME\" arch=\"$PKG_ARCH\">"
		echo "<version epoch=\"0\" ver=\"$VERSION\" rel=\"$RELEASE\"/>" 
		echo "$CHANGELOG"
		echo "</package>"
	done
}

yum_package_filelist_xml() {
	cat "$DISTCACHE/$COMP/binary-$ARCH/repodata/freight-pkglist" 2> /dev/null |
	while read PACKAGE 
	do
		PACKAGE="${PACKAGE##*/}"
		FILE="$DISTCACHE/.refs/$COMP/$PACKAGE"
		RPM_CACHE="$TMP/.rpm-info-cache/$DIST/$COMP/$PACKAGE"
		[ -d "$RPM_CACHE" ] || continue

		INFO="$RPM_CACHE/info"
		PKG_ID=$(cat "$RPM_CACHE/pkgid")
		FILE_LIST=$(cat "$RPM_CACHE/filelist")
		PKG_ARCH="$(yum_binary_arch "$INFO")"
		NAME="$(yum_binary_name "$INFO")"
		VERSION="$(yum_source_version "$(yum_binary_version "$INFO")")"
		RELEASE="$(yum_binary_release "$INFO")"
		PKG_FILES="$(yum_rpm_filelist_xml "$FILE_LIST" "\t")"

		echo "<package id=\"$PKG_ID\" name=\"$NAME\" arch=\"$PKG_ARCH\">"
		echo "<version epoch=\"0\" ver=\"$VERSION\" rel=\"$RELEASE\"/>" 
		echo "$PKG_FILES"
		echo "</package>"
	done
}

yum_primary_xml() {
	metadata_header="<metadata xmlns=\"http://linux.duke.edu/metadata/common\" \
xmlns:rpm=\"http://linux.duke.edu/metadata/rpm\" \
packages=\"$(yum_dist_arch_has_packages "$3" "$4")\">"
	package_metadata="$(yum_package_metadata_xml "$DIST" "$DISTCACHE" "$COMP" "$ARCH")"
	PRIMARY_XML="$(yum_xml_header)\n${metadata_header}\n${package_metadata}\n</metadata>"
	echo "$PRIMARY_XML"
}

yum_filelist_xml() {
	filelist_header="<filelists xmlns=\"http://linux.duke.edu/metadata/filelists\" \
packages=\"$(yum_dist_arch_has_packages "$3" "$4")\">"
	package_filelist="$(yum_package_filelist_xml "$DIST" "$DISTCACHE" "$COMP" "$ARCH")"
	FILELIST_XML="$(yum_xml_header)\n${filelist_header}\n${package_filelist}\n</filelists>"
	echo "$FILELIST_XML"
}

yum_other_xml() {
	otherdata_header="<otherdata xmlns=\"http://linux.duke.edu/metadata/other\" \
packages=\"$(yum_dist_arch_has_packages "$3" "$4")\">"
	package_otherdata="$(yum_package_otherdata_xml "$DIST" "$DISTCACHE" "$COMP" "$ARCH")"
	OTHER_XML="$(yum_xml_header)\n${otherdata_header}\n${package_otherdata}\n</otherdata>"
	echo "$OTHER_XML"
}

yum_repomd_entry_xml() {
	TYPE="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
	FILE="$2"

	echo "<data type=\"$TYPE\">"
	echo "<location href=\"repodata/$(basename "$FILE.gz")\"/>"
    	echo "<checksum type=\"sha\">$(yum_sha1 "$FILE.gz")</checksum>"
	echo "<timestamp>$(yum_filemtime "$FILE.gz")</timestamp>"
    	echo "<open-checksum type=\"sha\">$(yum_sha1 "$FILE")</open-checksum>"
	echo "</data>"
}

yum_repomd_xml() {
	PRIMARY_FILE="$1"
	FILELISTS_FILE="$2"
	OTHER_FILE="$3"

	echo "<repomd xmlns=\"http://linux.duke.edu/metadata/repomd\">"
	for i in PRIMARY FILELISTS OTHER
	do
		echo "$(yum_repomd_entry_xml "$i" "$( eval echo "\$${i}_FILE")")"
	done
	echo "</repomd>"
}

# Setup the repository for the distro named in the first argument,
# including all packages read from `stdin`.
yum_cache() {
	DIST="$1"

	# Generate a timestamp to use in this build's directory name.
	DATE="$(date +%Y%m%d%H%M%S%N)"
	DISTCACHE="$VARCACHE/dists/$DIST-$DATE"

	# For a Debian archive, each distribution needs at least this directory
	# structure in place.  The directory for this build must not exist,
	# otherwise this build would clobber a previous one.  The `.refs`
	# directory contains links to all the packages currently included in
	# this distribution to enable cleaning by link count later.
	mkdir -p "$DISTCACHE/.refs"
	mkdir -p "$VARCACHE/pool/$DIST"

	# Work through every package that should be part of this distro.
	while read PATHNAME
	do

		# Extract the component, if present, from the package's pathname.
		case "$PATHNAME" in
			*/*) COMP="${PATHNAME%%/*}" PACKAGE="${PATHNAME##*/}";;
			*) COMP="main" PACKAGE="$PATHNAME";;
		esac

		case "$PATHNAME" in

			# Source RPMs.
			*.src.rpm) yum_cache_source "$DIST" "$DISTCACHE" "$PATHNAME" "$COMP" "$PACKAGE";;
			# Binary packages.
			*.rpm) yum_cache_binary "$DIST" "$DISTCACHE" "$PATHNAME" "$COMP" "$PACKAGE";;

			*) echo "# [freight] skipping extraneous file $PATHNAME" >&2;;
		esac
	done
	COMPS="$(ls "$DISTCACHE")"

	# Build a `Release` file for each component and architecture.  `gzip`
	# the `Packages` file, too.
	for COMP in $COMPS
	do
		for ARCH in $YUM_ARCHS
		do
			primary_file="$DISTCACHE/$COMP/binary-$ARCH/repodata/primary.xml"
			filelist_file="$DISTCACHE/$COMP/binary-$ARCH/repodata/filelists.xml"
			other_file="$DISTCACHE/$COMP/binary-$ARCH/repodata/other.xml"

			PRIMARY_XML=$(yum_primary_xml "$DIST" "$DISTCACHE" "$COMP" "$ARCH")
			echo "${PRIMARY_XML}" > "$primary_file"

			FILELIST_XML=$(yum_filelist_xml "$DIST" "$DISTCACHE" "$COMP" "$ARCH")
			echo "${FILELIST_XML}" > "$filelist_file"

			OTHER_XML=$(yum_other_xml "$DIST" "$DISTCACHE" "$COMP" "$ARCH")
			echo "${OTHER_XML}" > "$other_file"

			find "$DISTCACHE/$COMP/binary-$ARCH/repodata" -type f -name "*.xml" |
			while read FILE
			do
				gzip -c "$FILE" > "$FILE.gz"
			done

			REPOMD_XML=$(yum_repomd_xml "$primary_file" "$filelist_file" "$other_file")

			rm -f "$DISTCACHE/$COMP/binary-$ARCH/repodata/primary.xml" \
				"$DISTCACHE/$COMP/binary-$ARCH/repodata/filelists.xml" \
				"$DISTCACHE/$COMP/binary-$ARCH/repodata/other.xml"

			echo "${REPOMD_XML}" > "$DISTCACHE/$COMP/binary-$ARCH/repodata/repomd.xml"

			gpg -abs$([ "$TTY" ] || echo " --no-tty") --use-agent -u"$GPG" \
				--detach-sign --armor \
				"$DISTCACHE/$COMP/binary-$ARCH/repodata/repomd.xml" || {
				cat <<EOF
# [freight] couldn't sign the repository, perhaps you need to run
# [freight] gpg --gen-key and update the GPG setting in $CONF
# [freight] (see freight(5) for more information)
EOF
				rm -rf "$DISTCACHE"
				exit 1
			}
		done
	done

	#FIME: this is called for all managers, should only do it once
	# Generate `pubkey.gpg` containing the plaintext public key and
	# `keyring.gpg` containing a complete GPG keyring containing only
	# the appropriate public key.
	mkdir -m700 -p "$TMP/gpg"
	gpg -q --export -a "$GPG" |
	tee "$VARCACHE/pubkey.gpg" |
	gpg -q --homedir "$TMP/gpg" --import
	chmod 644 "$TMP/gpg/pubring.gpg"
	mv "$TMP/gpg/pubring.gpg" "$VARCACHE/keyring.gpg"

	# Move the symbolic link for this distro to this build.
	ln -s "$DIST-$DATE" "$DISTCACHE-"
	OLD="$(readlink "$VARCACHE/dists/$DIST" || true)"
	mv -T "$DISTCACHE-" "$VARCACHE/dists/$DIST"
	[ -z "$OLD" ] || rm -rf "$VARCACHE/dists/$OLD"

}

# Add a binary package to the given dist and to the pool.
yum_cache_binary() {
	DIST="$1"
	DISTCACHE="$2"
	PATHNAME="$3"
	COMP="$4"
	PACKAGE="$5"

	# Verify this package by way of extracting its control information
	# to be used throughout this iteration of the loop.
	mkdir -p "$TMP/.rpm-info-cache/$DIST/$COMP/$PACKAGE"

	rpm --query --package --queryformat="${RPM_QUERY_FORMAT}" "$VARLIB/yum/$DIST/$PATHNAME" > "$TMP/.rpm-info-cache/$DIST/$COMP/$PACKAGE/info" 2> /dev/null || {
		echo "# [freight] skipping invalid RPM package $PATHNAME" >&2
		return 1
	}
	rpm --query --package --queryformat="[%{FILENAMES}\t%{FILECLASS}\n]" "$VARLIB/yum/$DIST/$PATHNAME" > "$TMP/.rpm-info-cache/$DIST/$COMP/$PACKAGE/filelist" 2> /dev/null || {
		echo "# [freight] skipping invalid RPM package $PATHNAME" >&2
		return 1
	}
	rpm --query --package --queryformat="[* %{CHANGELOGTIME} %{CHANGELOGNAME}\n%{CHANGELOGTEXT}\n++freight-changelog-delim++\n]" "$VARLIB/yum/$DIST/$PATHNAME" > "$TMP/.rpm-info-cache/$DIST/$COMP/$PACKAGE/changelog" 2> /dev/null || {
		echo "# [freight] skipping invalid RPM package $PATHNAME" >&2
		return 1
	}
	echo "$(yum_sha1 "$VARLIB/yum/$DIST/$PATHNAME" 2> /dev/null)" > "$TMP/.rpm-info-cache/$DIST/$COMP/$PACKAGE/pkgid"

	# Create all architecture-specific directories.  This will allow
	# packages marked `all` to actually be placed in all architectures.
	for ARCH in $YUM_ARCHS
	do
		mkdir -p "$DISTCACHE/$COMP/binary-$ARCH/repodata"
	done


	# Link or copy this package into this distro's `.refs` directory.
	mkdir -p "$DISTCACHE/.refs/$COMP"
	ln "$VARLIB/yum/$DIST/$PATHNAME" "$DISTCACHE/.refs/$COMP" ||
	cp "$VARLIB/yum/$DIST/$PATHNAME" "$DISTCACHE/.refs/$COMP"

	# Package properties.  Remove the epoch from the version number
	# in the package filename, as is customary.
	INFO="$TMP/.rpm-info-cache/$DIST/$COMP/$PACKAGE/info"
	PKG_ARCH="$(yum_binary_arch "$INFO")"
	NAME="$(yum_binary_name "$INFO")"
	VERSION="$(yum_binary_version "$INFO")"
	PREFIX="$(yum_binary_prefix "$INFO")"
	SOURCE="$(yum_binary_sourcename "$INFO")"
	FILENAME="${NAME}-${VERSION##*:}.${PKG_ARCH}.rpm"

	 # Link this package into the pool.
	 POOL="pool/$DIST/$COMP/$PREFIX/$SOURCE"
	 mkdir -p "$VARCACHE/$POOL"
	 if [ ! -f "$VARCACHE/$POOL/$FILENAME" ]
	 then
		if [ "$PACKAGE" != "$FILENAME" ]
			then echo "# [freight] adding $PACKAGE to pool (as $FILENAME)" >&2
			else echo "# [freight] adding $PACKAGE to pool" >&2
		fi
		ln "$DISTCACHE/.refs/$COMP/$PACKAGE" "$VARCACHE/$POOL/$FILENAME"
	 fi

	# Build a list of the one-or-more `Packages` files to append with
	# this package's info.
	if [ "$PKG_ARCH" = "noarch" ]; then
		FILES="$(find "$DISTCACHE/$COMP" -type f -name "freight-pkglist")"
	elif [ "$PKG_ARCH" = "i686" ]; then
		FILES="$DISTCACHE/$COMP/binary-i386/repodata/freight-pkglist"
	else
		FILES="$DISTCACHE/$COMP/binary-$ARCH/repodata/freight-pkglist"
	fi

	echo "$FILENAME" | tee -a $FILES >/dev/null
}

# FIXME: add support for SRCRPMs
yum_cache_source() {
	return
}
## Add a source package to the given dist and to the pool.  *.orig.tar.gz and
## *.diff.gz will be found based on PATHNAME and associated with the correct
## source package.
#yum_cache_source() {
#	DIST="$1"
#	DISTCACHE="$2"
#	PATHNAME="$3"
#	COMP="$4"
#	PACKAGE="$5"
#
#	NAME="$(yum_source_name "$PATHNAME")"
#	VERSION="$(yum_source_version "$PATHNAME")"
#	ORIG_VERSION="$(yum_source_version "$PATHNAME")"
#	DIRNAME="$(dirname "$PATHNAME")"
#	DSC_FILENAME="${NAME}_${VERSION%*:}.dsc"
#	DEBTAR_FILENAME="${NAME}_${VERSION%*:}.debian.tar.gz"
#	DIFFGZ_FILENAME="${NAME}_${VERSION%*:}.diff.gz"
#	ORIG_FILENAME="${NAME}_${ORIG_VERSION}.orig.tar.gz"
#
#	if [ -f "$VARLIB/yum/$DIST/$DIRNAME/$DEBTAR_FILENAME" ]
#	then DIFF_FILENAME=${DEBTAR_FILENAME}
#	else DIFF_FILENAME=${DIFFGZ_FILENAME}
#	fi
#
#	# Verify this package by ensuring the other necessary files are present.
#	[ -f "$VARLIB/yum/$DIST/$DIRNAME/$ORIG_FILENAME" \
#	-a -f "$VARLIB/yum/$DIST/$DIRNAME/$DIFF_FILENAME" ] || {
#		echo "# [freight] skipping invalid Debian source package $PATHNAME" >&2
#		return
#	}
#
#	# Create the architecture-parallel source directory and manifest.
#	mkdir -p "$DISTCACHE/$COMP/source"
#	touch "$DISTCACHE/$COMP/source/Sources"
#
#	# Link or copy this source package into this distro's `.refs` directory
#	# if it isn't already there (which can happen when two packages derive
#	# from the same original tarball).
#	mkdir -p "$DISTCACHE/.refs/$COMP"
#	for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME"
#	do
#		[ -f "$DISTCACHE/.refs/$COMP/$FILENAME" ] ||
#		ln "$VARLIB/yum/$DIST/$DIRNAME/$FILENAME" "$DISTCACHE/.refs/$COMP" ||
#		cp "$VARLIB/yum/$DIST/$DIRNAME/$FILENAME" "$DISTCACHE/.refs/$COMP"
#	done
#
#	# Package properties.  Remove the epoch from the version number
#	# in the package filename, as is customary.
#
#	# Link this source package into the pool.
#	POOL="pool/$DIST/$COMP/$(yum_prefix "$NAME")/$NAME"
#	mkdir -p "$VARCACHE/$POOL"
#	for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME"
#	do
#		if [ ! -f "$VARCACHE/$POOL/$FILENAME" ]
#		then
#			echo "# [freight] adding $FILENAME to pool" >&2
#			ln "$DISTCACHE/.refs/$COMP/$FILENAME" "$VARCACHE/$POOL"
#		fi
#	done
#
#	# Grab and augment the control fields from this source package.  Remove
#	# and recalculate file checksums.  Change the `Source` field to `Package`.
#	# Add the `Directory` field.
#	{
#		egrep "^[A-Z][^:]+: ." "$VARLIB/yum/$DIST/$PATHNAME" |
#		egrep -v "^(Version: GnuPG|Hash: )" |
#		sed "s/^Source:/Package:/"
#		echo "Directory: $POOL"
#		echo "Files:"
#		for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME"
#		do
#			SIZE="$(yum_filesize "$VARCACHE/$POOL/$FILENAME")"
#			MD5="$(yum_md5 "$VARCACHE/$POOL/$FILENAME")"
#			echo " $MD5 $SIZE $FILENAME"
#		done
#		echo "Checksums-Sha1:"
#		for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME"
#		do
#			SIZE="$(yum_filesize "$VARCACHE/$POOL/$FILENAME")"
#			SHA1="$(yum_sha1 "$VARCACHE/$POOL/$FILENAME")"
#			echo " $SHA1 $SIZE $FILENAME"
#		done
#		echo "Checksums-Sha256:"
#		for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME"
#		do
#			SIZE="$(yum_filesize "$VARCACHE/$POOL/$FILENAME")"
#			SHA256="$(yum_sha256 "$VARCACHE/$POOL/$FILENAME")"
#			echo " $SHA256 $SIZE $FILENAME"
#		done
#		echo
#	} >>"$DISTCACHE/$COMP/source/Sources"
#
#}

# Clean up old packages in the pool.
yum_clean() {
	find "$VARCACHE/pool" -links 1 -delete || true
}
