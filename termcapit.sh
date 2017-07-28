#!/bin/bash

function usage {
cat <<EOU
Usage:
  ${0##*/} [-h] [-d] [-t <termcap>] <update>

Updates termacp file with entries from update avoiding duplicates.. If termcap
file gets changed the original termcap file is backed like this:
  /etc/termcap -> /etc/termcap.2017-07-28-11-47-19.backup

Options:
  h - Print usage and exit
  t - Path to termcap file, if not specified defaults to /etc/termcap
  d - Delete entries featured in the update file from the termcap file

EOU
}

function add_to_cleanable {
	_CLEANABLE="${_CLEANABLE}$(printf '%s%q' "${_CLEANABLE:+" "}" "${1%|*}")"
}

function cleanup {
	rm -rf $_CLEANABLE
}

function brag_and_exit {
	if [ -n "$1" ] ; then
		ERR_MESSAGE="$1"
	else
		ERR_MESSAGE='Something went terribly wrong'
	fi

	echo 'Error: '"$ERR_MESSAGE"$'\n' >&2
	usage >&2

	cleanup

	exit 1
}

function leave_with_dignity {
	cleanup

	exit 0
}

read -r -d '' SED_JOIN << EOSJ
: repeat
/\\\\$/ {
	N
	s/\\\\\n[[:blank:]]*/@NEWLINE@/
	t repeat
}
EOSJ

read -r -d '' SED_SPLIT << EOSS
s/@NEWLINE@/\\\\\\
	/g
EOSS


INSTALL_UPDATE=YES


while getopts ":t:hd" O ; do
	case $O in
		h)
			usage
			exit
			;;
		t)
			SOURCE="$OPTARG"
			;;
		d)
			INSTALL_UPDATE=NO
			;;
	esac
done


UPDATE="${!OPTIND}"
[ -n "$UPDATE" ] || brag_and_exit "Update file not found"

SOURCE="${SOURCE-/etc/termcap}"


COMPILED_TMP="$(mktemp /tmp/${0##*/}_compiled.XXXXXXXXXX)" || brag_and_exit "Can not create temp file for compiling"
add_to_cleanable "$COMPILED_TMP"
COMPILED_IS_EMPTY=YES

if [ -f "$SOURCE" ] ; then
	[ -w "$SOURCE" ] || brag_and_exit "Can not write to termcap file $SOURCE"

	JOINED_TMP="$(mktemp /tmp/${0##*/}_joined.XXXXXXXXXX)" || brag_and_exit "Can not create temp file for joining"
	add_to_cleanable "$JOINED_TMP"

	sed -E -e "$SED_JOIN" < "$SOURCE" >> "$JOINED_TMP"

	# Compose the list of entry names to be updated
	while IFS='' read -r LINE ; do
		# Skip unless this line starts a new entry
		grep -Eq '^[[:alnum:]][^[:blank:]]+\|.' <<< $LINE || continue
	
		# Lose description, escape and add to the list of potentially overlapping names
		OVERLAP_NAMES="${OVERLAP_NAMES}$(printf '%s%q' "${OVERLAP_NAMES:+|}" "${LINE%|*}")" 
	done < "$UPDATE"

	if grep -Eq "^($OVERLAP_NAMES)[:|]" < "$JOINED_TMP" ; then
		grep -vE "^($OVERLAP_NAMES)[:|]" < "$JOINED_TMP" | sed -e "$SED_SPLIT" >> "$COMPILED_TMP"
		BACKUP_NEEDED=YES
	else
		cat "$SOURCE" >> "$COMPILED_TMP"
	fi
	COMPILED_IS_EMPTY=NO
elif [ ! -e "$SOURCE" ] ; then
	if [ "$INSTALL_UPDATE" == 'YES' ] ; then
		touch "$SOURCE" 2>/dev/null || brag_and_exit "Can not create termcap file $SOURCE"
	else
		leave_with_dignity
	fi
else
	brag_and_exit "Not a termcap file $SOURCE"
fi

if [ "$INSTALL_UPDATE" == 'YES' ] ; then
	[ "$COMPILED_IS_EMPTY" != 'YES' ] && BACKUP_NEEDED=YES
	cat "$UPDATE" >> "$COMPILED_TMP" 
	COMPILED_IS_EMPTY=NO
fi

if [ "$BACKUP_NEEDED" = 'YES' ] ; then 
	BACKUP="$SOURCE.$(date +%Y-%m-%d-%H-%M-%S).backup"
	cp -a "$SOURCE" "$BACKUP" || brag_and_exit "Can not backup $SOURCE to $BACKUP"
fi

if [ "$COMPILED_IS_EMPTY" != 'YES' ] ; then
	(
		cat "$COMPILED_TMP" > "$SOURCE" || brag_and_exit "Can not write updated termcap to $SOURCE"
	) 2>/dev/null; 
fi


leave_with_dignity
