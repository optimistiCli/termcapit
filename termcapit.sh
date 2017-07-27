#!/bin/bash

function usage {
cat <<EOU
Usage:
  ${0##*/} <update> [<termcap>]

Updates termacp file with entries from update avoiding duplicates. If path 
to termcap is not specified /etc/termcap is used.

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

UPDATE="$1"
[ -f "$UPDATE" ] || brag_and_exit "Update file not found"

SOURCE="${2-/etc/termcap}"

COMPILED_TMP="$(mktemp /tmp/${0##*/}_compiled.XXXXXXXXXX)" || brag_and_exit "Can not create temp file for compiling"
add_to_cleanable "$COMPILED_TMP"

if [ -f "$SOURCE" ] ; then
	[ -w "$SOURCE" ] || brag_and_exit "Can not write to termcap file $SOURCE"

	BACKUP_NEEDED=YES

	JOINED_TMP="$(mktemp /tmp/${0##*/}_joined.XXXXXXXXXX)" || brag_and_exit "Can not create temp file for joining"
	add_to_cleanable "$JOINED_TMP"

	sed -E -e "$SED_JOIN" < "$SOURCE" >> "$JOINED_TMP"

	# Compose the list of entry names to be updated
	while IFS='' read -r LINE ; do
		# Skip unless this line starts a new entry
		grep -Eq '^[[:alnum:]][^[:blank:]]+\|.' <<< $LINE || continue
	
		# Loose description, escape and add to the list of potentially overlapping names
		OVERLAP_NAMES="${OVERLAP_NAMES}$(printf '%s%q' "${OVERLAP_NAMES:+|}" "${LINE%|*}")" 
	done < "$UPDATE"

	grep -vE "^($OVERLAP_NAMES)[:|]" < "$JOINED_TMP" | sed -e "$SED_SPLIT" >> "$COMPILED_TMP"
elif [ ! -e "$SOURCE" ] ; then
	touch "$SOURCE" 2>/dev/null || brag_and_exit "Can not create termcap file $SOURCE"
else
	brag_and_exit "Not a termcap file $SOURCE"
fi

cat "$UPDATE" >> "$COMPILED_TMP" 

if [ "$BACKUP_NEEDED" = 'YES' ] ; then 
	BACKUP="$SOURCE.$(date +%Y-%m-%d-%H-%M-%S).backup"
	cp -a "$SOURCE" "$BACKUP" || brag_and_exit "Can not backup $SOURCE to $BACKUP"
fi

(
	cat "$COMPILED_TMP" > "$SOURCE" || brag_and_exit "Can not write updated termcap to $SOURCE"
) 2>/dev/null; 


cleanup
