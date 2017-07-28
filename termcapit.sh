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

function cook_temp_file {
	local tempfile=
	tempfile="$(mktemp /tmp/${0##*/}_${1-temp}.XXXXXXXXXX 2>/dev/null)" || brag_and_exit "Can not create temp file${1:+ for $1}"
	add_to_cleanable "$tempfile"

	LAST_COOCKED_TEMP_FILE="$tempfile"
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


cook_temp_file compiling ; COMPILING_TMP="$LAST_COOCKED_TEMP_FILE"
COMPILING_IS_EMPTY=YES

if [ -f "$SOURCE" ] ; then
	[ -w "$SOURCE" ] || brag_and_exit "Can not write to termcap file $SOURCE"

	cook_temp_file joining ; JOINING_TMP="$LAST_COOCKED_TEMP_FILE"

	sed -E -e "$SED_JOIN" < "$SOURCE" >> "$JOINING_TMP"

	# Compose the list of entry names to be updated
	while IFS='' read -r LINE ; do
		# Skip unless this line starts a new entry
		grep -Eq '^[[:alnum:]][^[:blank:]]+\|.' <<< $LINE || continue
	
		# Lose description, escape and add to the list of potentially overlapping names
		OVERLAP_NAMES="${OVERLAP_NAMES}$(printf '%s%q' "${OVERLAP_NAMES:+|}" "${LINE%|*}")" 
	done < "$UPDATE"

	if grep -Eq "^($OVERLAP_NAMES)[:|]" < "$JOINING_TMP" ; then
		grep -vE "^($OVERLAP_NAMES)[:|]" < "$JOINING_TMP" | sed -e "$SED_SPLIT" >> "$COMPILING_TMP"
		BACKUP_NEEDED=YES
	else
		cat "$SOURCE" >> "$COMPILING_TMP"
	fi
	COMPILING_IS_EMPTY=NO
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
	[ "$COMPILING_IS_EMPTY" != 'YES' ] && BACKUP_NEEDED=YES
	cat "$UPDATE" >> "$COMPILING_TMP" 
	COMPILING_IS_EMPTY=NO
fi

if [ "$BACKUP_NEEDED" = 'YES' ] ; then 
	BACKUP="$SOURCE.$(date +%Y-%m-%d-%H-%M-%S).backup"
	cp -a "$SOURCE" "$BACKUP" || brag_and_exit "Can not backup $SOURCE to $BACKUP"
fi

if [ "$COMPILING_IS_EMPTY" != 'YES' ] ; then
	(
		cat "$COMPILING_TMP" > "$SOURCE" || brag_and_exit "Can not write updated termcap to $SOURCE"
	) 2>/dev/null; 
fi


leave_with_dignity
