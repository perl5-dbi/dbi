# DBI - The Perl Database Interface.

[![Build Status](https://secure.travis-ci.org/perl5-dbi/dbi.png)](http://travis-ci.org/perl5-dbi/dbi/)

See [COPYRIGHT](https://metacpan.org/module/DBI#COPYRIGHT)
section in DBI.pm for usage and distribution rights.

See [GETTING HELP](https://metacpan.org/module/DBI#GETTING-HELP)
section in DBI.pm for how to get help.

# QUICK START GUIDE:

    The DBI requires one or more 'driver' modules to talk to databases,
    but they are not needed to build or install the DBI.

    Check that a DBD::* module exists for the database you wish to use.

    Install the DBI using a installer like cpanm, cpanplus, cpan,
    or whatever is recommened by the perl distribution you're using.
    Make sure the DBI tests run successfully before installing.

    Use the 'perldoc DBI' command to read the DBI documentation.

    Install the DBD::* driver module you wish to use in the same way.
    It is often important to read the driver README file carefully.
    Make sure the driver tests run successfully before installing.

The DBI.pm file contains the DBI specification and other documentation.
PLEASE READ IT. It'll save you asking questions on the mailing list
which you will be told are already answered in the documentation.

For more information and to keep informed about progress you can join
the a mailing list via mailto:dbi-users-help@perl.org
You can post to the mailing list without subscribing. (Your first post may be
delayed a day or so while it's being moderated.)

To help you make the best use of the dbi-users mailing list,
and any other lists or forums you may use, I strongly
recommend that you read "How To Ask Questions The Smart Way"
by Eric Raymond:
 
  http://www.catb.org/~esr/faqs/smart-questions.html

Much useful information and online archives of the mailing lists can be
found at http://dbi.perl.org/

See also http://metacpan.org/


# IF YOU HAVE PROBLEMS:

First, read the notes in the INSTALL file.

If you can't fix it your self please post details to dbi-users@perl.org.
Please include:

1. A complete log of a complete build, e.g.:

    perl Makefile.PL           (do a make realclean first)
    make
    make test
    make test TEST_VERBOSE=1   (if any of the t/* tests fail)

2. The output of perl -V

3. If you get a core dump, try to include a stack trace from it.

    Try installing the Devel::CoreStack module to get a stack trace.
    If the stack trace mentions XS_DynaLoader_dl_load_file then rerun
    make test after setting the environment variable PERL_DL_DEBUG to 2.

4. If your installation succeeds, but your script does not behave
   as you expect, the problem is possibly in your script.

    Before sending to dbi-users, try writing a small, easy to use test case to
    reproduce your problem. Also, use the DBI->trace method to trace your
    database calls.

Please don't post problems to usenet, google groups or perl5-porters.
This software is supported via the dbi-users mailing list.  For more
information and to keep informed about progress you can join the
mailing list via mailto:dbi-users-help@perl.org
(please note that I do not run or manage the mailing list).

It is important to check that you are using the latest version before
posting. If you're not then we're very likely to simply say "upgrade to
the latest". You would do yourself a favour by upgrading beforehand.

Please remember that we're all busy. Try to help yourself first,
then try to help us help you by following these guidelines carefully.

Regards,
Tim Bunce and the perl5-dbi team.
