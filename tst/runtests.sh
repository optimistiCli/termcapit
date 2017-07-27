#!/bin/bash

TESTED='../termcapit.sh'

function report_test_result {
	local test_name="$1"
	local test_exit_code="$2"

	if [ "$test_exit_code" -eq 0 ] ; then
		test_ok=Pass
	else
		test_ok=Fail
	fi

	echo "$test_name :: $test_ok"
}

[ "$(id -u)" -lt 500 ] && echo 'Should run as pedestrian user, NOT as root' && exit 1
sudo -v || exit 1

ALL_OK=0

TEST_NAME='No arguments -> Error'
"$TESTED" >/dev/null 2>/dev/null ;  [ "$?" -ne 0 ] ; EXIT_CODE="$?"
report_test_result "$TEST_NAME" "$EXIT_CODE"
[ "$EXIT_CODE" -eq 0 ] || ALL_OK=1

TEST_NAME='Source is dir -> Error'
TST_DIR="$(mktemp -d /tmp/${0##*/}_${TESTED##*/}.XXXXXXXXXX)"
"$TESTED" screen-termcap "$TST_DIR" >/dev/null 2>/dev/null ;  [ "$?" -ne 0 ] ; EXIT_CODE="$?"
report_test_result "$TEST_NAME" "$EXIT_CODE"
[ "$EXIT_CODE" -eq 0 ] || ALL_OK=1
rmdir "$TST_DIR"

TEST_NAME='Source not writable -> Error'
TST_SOURCE="$(sudo -n mktemp /tmp/${0##*/}_${TESTED##*/}.XXXXXXXXXX)"
cat dsm-termcap | sudo -n tee -a "$TST_SOURCE" >/dev/null
"$TESTED" screen-termcap "$TST_SOURCE" >/dev/null 2>/dev/null ;  [ "$?" -ne 0 ] ; EXIT_CODE="$?"
report_test_result "$TEST_NAME" "$EXIT_CODE"
[ "$EXIT_CODE" -eq 0 ] || ALL_OK=1
sudo -n rm "$TST_SOURCE"

TEST_NAME='No source in a non writable dir -> Error'
TST_DIR="$(sudo -n mktemp -d /tmp/${0##*/}_${TESTED##*/}.XXXXXXXXXX)"
"$TESTED" screen-termcap "$TST_DIR"/termcap >/dev/null 2>/dev/null ;  [ "$?" -ne 0 ] ; EXIT_CODE="$?"
report_test_result "$TEST_NAME" "$EXIT_CODE"
[ "$EXIT_CODE" -eq 0 ] || ALL_OK=1
sudo -n rmdir "$TST_DIR"

TEST_NAME='Source does nor exist -> result == update & no backup'
TST_SOURCE="$(mktemp /tmp/${0##*/}_${TESTED##*/}.XXXXXXXXXX)"
rm "$TST_SOURCE"
BACKUP="$TST_SOURCE.????-??-??-??-??-??.backup"
"$TESTED" screen-termcap "$TST_SOURCE" >/dev/null 2>/dev/null ; EXIT_CODE="$?"
if [ "$EXIT_CODE" -eq 0 ] ; then
	diff screen-termcap "$TST_SOURCE" >/dev/null 2>/dev/null ; EXIT_CODE="$?"
	if [ "$EXIT_CODE" -eq 0 ] ; then
		ls -1 $BACKUP >/dev/null 2>/dev/null ;  [ "$?" -ne 0 ] ; EXIT_CODE="$?"
	fi
fi
report_test_result "$TEST_NAME" "$EXIT_CODE"
[ "$EXIT_CODE" -eq 0 ] || ALL_OK=1
rm "$TST_SOURCE"

TEST_NAME='Source and update do not overlap -> result == source . update & backup'
TST_SOURCE="$(mktemp /tmp/${0##*/}_${TESTED##*/}.XXXXXXXXXX)"
cat dsm-termcap >> "$TST_SOURCE"
BACKUP="$TST_SOURCE.????-??-??-??-??-??.backup"
"$TESTED" screen-termcap "$TST_SOURCE" >/dev/null 2>/dev/null ; EXIT_CODE="$?"
if [ "$EXIT_CODE" -eq 0 ] ; then
	diff dsm-termcap+screen-termcap "$TST_SOURCE" >/dev/null 2>/dev/null ; EXIT_CODE="$?"
	if [ "$EXIT_CODE" -eq 0 ] ; then
		ls -1 $BACKUP >/dev/null 2>/dev/null ; EXIT_CODE="$?"
		if [ "$EXIT_CODE" -eq 0 ] ; then
			diff dsm-termcap $BACKUP >/dev/null 2>/dev/null ; EXIT_CODE="$?"
		fi
	fi
fi
report_test_result "$TEST_NAME" "$EXIT_CODE"
[ "$EXIT_CODE" -eq 0 ] || ALL_OK=1
rm "$TST_SOURCE" $BACKUP

TEST_NAME='Source and update DO overlap -> result == source - update .update & backup'
TST_SOURCE="$(mktemp /tmp/${0##*/}_${TESTED##*/}.XXXXXXXXXX)"
cat dsm-termcap >> "$TST_SOURCE"
BACKUP="$TST_SOURCE.????-??-??-??-??-??.backup"
"$TESTED" dsm-termcap-extract "$TST_SOURCE" >/dev/null 2>/dev/null ; EXIT_CODE="$?"
if [ "$EXIT_CODE" -eq 0 ] ; then
	diff dsm-termcap+dsm-termcap-extract "$TST_SOURCE" >/dev/null 2>/dev/null ; EXIT_CODE="$?"
	if [ "$EXIT_CODE" -eq 0 ] ; then
		ls -1 $BACKUP >/dev/null 2>/dev/null ; EXIT_CODE="$?"
		if [ "$EXIT_CODE" -eq 0 ] ; then
			diff dsm-termcap $BACKUP >/dev/null 2>/dev/null ; EXIT_CODE="$?"
		fi
	fi
fi
report_test_result "$TEST_NAME" "$EXIT_CODE"
[ "$EXIT_CODE" -eq 0 ] || ALL_OK=1
rm "$TST_SOURCE" $BACKUP


if [ "$ALL_OK" -eq 0 ] ; then
	echo "All tests succeded"
else
	echo "Some tests failed"
fi

exit "$ALL_OK"
