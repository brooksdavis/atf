#
# Automated Testing Framework (atf)
#
# Copyright (c) 2007, 2008, 2009 The NetBSD Foundation, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND
# CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

create_atffile()
{
    cat >Atffile <<EOF
Content-Type: application/X-atf-atffile; version="1"

prop: test-suite = atf

EOF
    for f in "${@}"; do
        echo "tp: ${f}" >>Atffile
    done
}

create_helper()
{
    cp $(atf_get_srcdir)/h_misc helper
    create_atffile helper
    TESTCASE=${1}; export TESTCASE
}

create_helper_stdin()
{
    cat >${1} <<EOF
#! $(atf-config -t atf_shell)
while [ \${#} -gt 0 ]; do
    if [ \${1} = -l ]; then
EOF
    _cnt=${2}
    while [ ${_cnt} -gt 0 ]; do
        echo "echo 'tc${_cnt}    Test case'" >>${1}
        _cnt=$((${_cnt} - 1))
    done
cat >>${1} <<EOF
        exit 0
    else
        shift
    fi
done
EOF
    cat >>${1}
}

atf_test_case config
config_head()
{
    atf_set "descr" "Tests that the config files are read in the correct" \
                    "order"
}
config_body()
{
    create_helper atf_run_config

    mkdir etc
    mkdir .atf

    echo "First: read system-wide common.conf."
    cat >etc/common.conf <<EOF
Content-Type: application/X-atf-config; version="1"

1st = "sw common"
2nd = "sw common"
3rd = "sw common"
4th = "sw common"
EOF
    atf_check -s eq:0 -o save:stdout -e ignore -x \
        "ATF_CONFDIR=$(pwd)/etc HOME=$(pwd) atf-run helper"
    atf_check -s eq:0 -o ignore -e ignore grep '1st: sw common' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '2nd: sw common' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '3rd: sw common' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '4th: sw common' stdout

    echo "Second: read system-wide <test-suite>.conf."
    cat >etc/atf.conf <<EOF
Content-Type: application/X-atf-config; version="1"

1st = "sw atf"
EOF
    atf_check -s eq:0 -o save:stdout -e ignore -x \
        "ATF_CONFDIR=$(pwd)/etc HOME=$(pwd) atf-run helper"
    atf_check -s eq:0 -o ignore -e ignore grep '1st: sw atf' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '2nd: sw common' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '3rd: sw common' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '4th: sw common' stdout

    echo "Third: read user-specific common.conf."
    cat >.atf/common.conf <<EOF
Content-Type: application/X-atf-config; version="1"

2nd = "us common"
EOF
    atf_check -s eq:0 -o save:stdout -e ignore -x \
        "ATF_CONFDIR=$(pwd)/etc HOME=$(pwd) atf-run helper"
    atf_check -s eq:0 -o ignore -e ignore grep '1st: sw atf' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '2nd: us common' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '3rd: sw common' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '4th: sw common' stdout

    echo "Fourth: read user-specific <test-suite>.conf."
    cat >.atf/atf.conf <<EOF
Content-Type: application/X-atf-config; version="1"

3rd = "us atf"
EOF
    atf_check -s eq:0 -o save:stdout -e ignore -x \
        "ATF_CONFDIR=$(pwd)/etc HOME=$(pwd) atf-run helper"
    atf_check -s eq:0 -o ignore -e ignore grep '1st: sw atf' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '2nd: us common' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '3rd: us atf' stdout
    atf_check -s eq:0 -o ignore -e ignore grep '4th: sw common' stdout
}

atf_test_case vflag
vflag_head()
{
    atf_set "descr" "Tests that the -v flag works and that it properly" \
                    "overrides the values in configuration files"
}
vflag_body()
{
    create_helper atf_run_testvar

    echo "Checking that 'testvar' is not defined."
    atf_check -s eq:1 -o ignore -e ignore -x \
        "ATF_CONFDIR=$(pwd)/etc atf-run helper"

    echo "Checking that defining 'testvar' trough '-v' works."
    atf_check -s eq:0 -o save:stdout -e ignore -x \
        "ATF_CONFDIR=$(pwd)/etc atf-run -v testvar='a value' helper"
    atf_check -s eq:0 -o ignore -e ignore grep 'testvar: a value' stdout

    echo "Checking that defining 'testvar' trough the configuration" \
         "file works."
    mkdir etc
    cat >etc/common.conf <<EOF
Content-Type: application/X-atf-config; version="1"

testvar = "value in conf file"
EOF
    atf_check -s eq:0 -o save:stdout -e ignore -x \
              "ATF_CONFDIR=$(pwd)/etc atf-run helper"
    atf_check -s eq:0 -o ignore -e ignore \
              grep 'testvar: value in conf file' stdout

    echo "Checking that defining 'testvar' trough -v overrides the" \
         "configuration file."
    atf_check -s eq:0 -o save:stdout -e ignore -x \
        "ATF_CONFDIR=$(pwd)/etc atf-run -v testvar='a value' helper"
    atf_check -s eq:0 -o ignore -e ignore grep 'testvar: a value' stdout
}

atf_test_case atffile
atffile_head()
{
    atf_set "descr" "Tests that the variables defined by the Atffile" \
                    "are recognized and that they take the lowest priority"
}
atffile_body()
{
    create_helper atf_run_testvar

    echo "Checking that 'testvar' is not defined."
    atf_check -s eq:1 -o ignore -e ignore -x \
              "ATF_CONFDIR=$(pwd)/etc atf-run helper"

    echo "Checking that defining 'testvar' trough the Atffile works."
    echo 'conf: testvar = "a value"' >>Atffile
    atf_check -s eq:0 -o save:stdout -e ignore -x \
              "ATF_CONFDIR=$(pwd)/etc atf-run helper"
    atf_check -s eq:0 -o ignore -e ignore \
              grep 'testvar: a value' stdout

    echo "Checking that defining 'testvar' trough the configuration" \
         "file overrides the one in the Atffile."
    mkdir etc
    cat >etc/common.conf <<EOF
Content-Type: application/X-atf-config; version="1"

testvar = "value in conf file"
EOF
    atf_check -s eq:0 -o save:stdout -e ignore -x \
              "ATF_CONFDIR=$(pwd)/etc atf-run helper"
    atf_check -s eq:0 -o ignore -e ignore \
              grep 'testvar: value in conf file' stdout
    rm -rf etc

    echo "Checking that defining 'testvar' trough -v overrides the" \
         "one in the Atffile."
    atf_check -s eq:0 -o save:stdout -e ignore -x \
        "ATF_CONFDIR=$(pwd)/etc atf-run -v testvar='new value' helper"
    atf_check -s eq:0 -o ignore -e ignore grep 'testvar: new value' stdout
}

atf_test_case atffile_recursive
atffile_recursive_head()
{
    atf_set "descr" "Tests that variables defined by an Atffile are not" \
                    "inherited by other Atffiles."
}
atffile_recursive_body()
{
    create_helper atf_run_testvar

    mkdir dir
    mv Atffile helper dir

    echo "Checking that 'testvar' is not inherited."
    create_atffile dir
    echo 'conf: testvar = "a value"' >> Atffile
    atf_check -s eq:1 -o ignore -e ignore -x "ATF_CONFDIR=$(pwd)/etc atf-run"

    echo "Checking that defining 'testvar' in the correct Atffile works."
    echo 'conf: testvar = "a value"' >>dir/Atffile
    atf_check -s eq:0 -o save:stdout -e ignore -x \
              "ATF_CONFDIR=$(pwd)/etc atf-run"
    atf_check -s eq:0 -o ignore -e ignore grep 'testvar: a value' stdout
}

atf_test_case fds
fds_head()
{
    atf_set "descr" "Tests that all streams are properly captured"
}
fds_body()
{
    create_helper atf_run_fds

    atf_check -s eq:0 -o save:stdout -e empty atf-run
    atf_check -s eq:0 -o ignore -e empty grep '^tc-so:msg1 to stdout$' stdout
    atf_check -s eq:0 -o ignore -e empty grep '^tc-so:msg2 to stdout$' stdout
    atf_check -s eq:0 -o ignore -e empty grep '^tc-se:msg1 to stderr$' stdout
    atf_check -s eq:0 -o ignore -e empty grep '^tc-se:msg2 to stderr$' stdout
}

atf_test_case broken_tp_hdr
broken_tp_hdr_head()
{
    atf_set "descr" "Ensures that atf-run reports test programs that" \
                    "provide a bogus header as broken programs"
}
broken_tp_hdr_body()
{
    # We produce two errors from the header to ensure that the parse
    # errors are printed on a single line on the output file.  Printing
    # them on separate lines would be incorrect.
    create_helper_stdin helper 1 <<EOF
echo 'foo' 1>&9
echo 'bar' 1>&9
exit 0
EOF
    chmod +x helper

    create_atffile helper

    atf_check -s eq:1 -o save:stdout -e empty atf-run
    atf_check -s eq:0 -o ignore -e empty \
              grep '^tc-end: tc1, .*Line 1.*Line 2' stdout
}

atf_test_case broken_tp_list
broken_tp_list_head()
{
    atf_set "descr" "Ensures that atf-run reports test programs that" \
                    "provide a bogus test case list"
}
broken_tp_list_body()
{
    cat >helper <<EOF
#! $(atf-config -t atf_shell)
while [ \${#} -gt 0 ]; do
    if [ \${1} = -l ]; then
        echo 'no_desc'
        exit 0
    else
        shift
    fi
done
exit 0
EOF
    chmod +x helper

    create_atffile helper

    atf_check -s eq:1 -o save:stdout -e empty atf-run
    atf_check -s eq:0 -o save:stdout -e empty grep '^tp-end: helper, ' stdout
    atf_check -s eq:0 -o ignore -e empty grep 'test case list.*no_desc' stdout
}

atf_test_case failed_tp_list
failed_tp_list_head()
{
    atf_set "descr" "Ensures that atf-run reports test programs that" \
                    "fail when listing test cases"
}
failed_tp_list_body()
{
    cat >helper <<EOF
#! $(atf-config -t atf_shell)
exit 1
EOF
    chmod +x helper

    create_atffile helper

    atf_check -s eq:1 -o save:stdout -e empty atf-run
    atf_check -s eq:0 -o save:stdout -e empty grep '^tp-end: helper, ' stdout
    atf_check -s eq:0 -o ignore -e empty grep 'failure exit status' stdout
}

atf_test_case zero_tcs
zero_tcs_head()
{
    atf_set "descr" "Ensures that atf-run reports test programs without" \
                    "test cases as errors"
}
zero_tcs_body()
{
    create_helper_stdin helper 0 <<EOF
echo 'Content-Type: application/X-atf-tcs; version="1"' 1>&9
echo 1>&9
echo "tcs-count: 0" 1>&9
exit 0
EOF
    chmod +x helper

    create_atffile helper

    atf_check -s eq:1 -o save:stdout -e empty atf-run
    atf_check -s eq:0 -o save:stdout -e empty grep '^tp-end: helper, ' stdout
    atf_check -s eq:0 -o ignore -e empty grep '0 test cases' stdout
}

atf_test_case exit_codes
exit_codes_head()
{
    atf_set "descr" "Ensures that atf-run reports bogus exit codes for" \
                    "programs correctly"
}
exit_codes_body()
{
    create_helper_stdin helper 1 <<EOF
echo 'Content-Type: application/X-atf-tcs; version="1"' 1>&9
echo 1>&9
echo "tcs-count: 1" 1>&9
echo "tc-start: tc1" 1>&9
echo "tc-end: tc1, failed, Yes, it failed" 1>&9
true
EOF
    chmod +x helper

    create_atffile helper

    atf_check -s eq:1 -o save:stdout -e empty atf-run
    cat stdout
    atf_check -s eq:0 -o save:stdout -e empty grep '^tc-end: tc1, ' stdout
    atf_check -s eq:0 -o ignore -e empty \
              grep 'success.*test cases failed' stdout
}

atf_test_case signaled
signaled_head()
{
    atf_set "descr" "Ensures that atf-run reports test program's crashes" \
                    "correctly"
}
signaled_body()
{
    create_helper_stdin helper 1 <<EOF
echo 'Content-Type: application/X-atf-tcs; version="1"' 1>&9
echo 1>&9
echo "tcs-count: 1" 1>&9
echo "tc-start: tc1" 1>&9
echo "tc-end: tc1, failed, Will fail" 1>&9
kill -9 \$\$
EOF
    chmod +x helper

    create_atffile helper

    atf_check -s eq:1 -o save:stdout -e empty atf-run
    atf_check -s eq:0 -o save:stdout -e empty grep '^tc-end: tc1, ' stdout
    atf_check -s eq:0 -o ignore -e empty grep 'received signal 9' stdout
}

atf_test_case no_reason
no_reason_head()
{
    atf_set "descr" "Ensures that atf-run reports bogus test programs" \
                    "that do not provide a reason for failed or skipped" \
                    "test cases"
}
no_reason_body()
{
    for r in failed skipped; do
        create_helper_stdin helper 1 <<EOF
echo 'Content-Type: application/X-atf-tcs; version="1"' 1>&9
echo 1>&9
echo "tcs-count: 1" 1>&9
echo "tc-start: tc1" 1>&9
echo "tc-end: tc1, ${r}" 1>&9
false
EOF
        chmod +x helper

        create_atffile helper

        atf_check -s eq:1 -o save:stdout -e empty atf-run
        atf_check -s eq:0 -o save:stdout -e empty \
                  grep '^tc-end: tc1, ' stdout
        atf_check -s eq:0 -o ignore -e empty \
                  grep 'Unexpected.*NEWLINE' stdout
    done
}

atf_test_case hooks
hooks_head()
{
    atf_set "descr" "Checks that the default hooks work and that they" \
                    "can be overriden by the user"
}
hooks_body()
{
    cp $(atf_get_srcdir)/h_pass helper
    create_atffile helper

    mkdir atf
    mkdir .atf

    echo "Checking default hooks"
    atf_check -s eq:0 -o save:stdout -e empty -x \
              "ATF_CONFDIR=$(pwd)/atf atf-run"
    atf_check -s eq:0 -o ignore -e empty grep '^info: time.start, ' stdout
    atf_check -s eq:0 -o ignore -e empty grep '^info: time.end, ' stdout

    echo "Checking the system-wide info_start hook"
    cat >atf/atf-run.hooks <<EOF
info_start_hook()
{
    atf_tps_writer_info "test" "sw value"
}
EOF
    atf_check -s eq:0 -o save:stdout -e empty -x \
              "ATF_CONFDIR=$(pwd)/atf atf-run"
    atf_check -s eq:0 -o ignore -e empty grep '^info: test, sw value' stdout
    atf_check -s eq:1 -o empty -e empty grep '^info: time.start, ' stdout
    atf_check -s eq:0 -o ignore -e empty grep '^info: time.end, ' stdout

    echo "Checking the user-specific info_start hook"
    cat >.atf/atf-run.hooks <<EOF
info_start_hook()
{
    atf_tps_writer_info "test" "user value"
}
EOF
    atf_check -s eq:0 -o save:stdout -e empty -x \
              "ATF_CONFDIR=$(pwd)/atf atf-run"
    atf_check -s eq:0 -o ignore -e empty \
              grep '^info: test, user value' stdout
    atf_check -s eq:1 -o empty -e empty grep '^info: time.start, ' stdout
    atf_check -s eq:0 -o ignore -e empty grep '^info: time.end, ' stdout

    rm atf/atf-run.hooks
    rm .atf/atf-run.hooks

    echo "Checking the system-wide info_end hook"
    cat >atf/atf-run.hooks <<EOF
info_end_hook()
{
    atf_tps_writer_info "test" "sw value"
}
EOF
    atf_check -s eq:0 -o save:stdout -e empty -x \
              "ATF_CONFDIR=$(pwd)/atf atf-run"
    atf_check -s eq:0 -o ignore -e empty grep '^info: time.start, ' stdout
    atf_check -s eq:1 -o empty -e empty grep '^info: time.end, ' stdout
    atf_check -s eq:0 -o ignore -e empty grep '^info: test, sw value' stdout

    echo "Checking the user-specific info_end hook"
    cat >.atf/atf-run.hooks <<EOF
info_end_hook()
{
    atf_tps_writer_info "test" "user value"
}
EOF
    atf_check -s eq:0 -o save:stdout -e empty -x \
              "ATF_CONFDIR=$(pwd)/atf atf-run"
    atf_check -s eq:0 -o ignore -e empty grep '^info: time.start, ' stdout
    atf_check -s eq:1 -o empty -e empty grep '^info: time.end, ' stdout
    atf_check -s eq:0 -o ignore -e empty \
              grep '^info: test, user value' stdout
}

atf_init_test_cases()
{
    atf_add_test_case config
    atf_add_test_case vflag
    atf_add_test_case atffile
    atf_add_test_case atffile_recursive
    atf_add_test_case fds
    atf_add_test_case broken_tp_hdr
    atf_add_test_case broken_tp_list
    atf_add_test_case failed_tp_list
    atf_add_test_case zero_tcs
    atf_add_test_case exit_codes
    atf_add_test_case signaled
    atf_add_test_case no_reason
    atf_add_test_case hooks
}

# vim: syntax=sh:expandtab:shiftwidth=4:softtabstop=4
