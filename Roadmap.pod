=head1 NAME

DBI ROADMAP - Planned Changes and Enhancements for the DBI

Tim Bunce - 5th October 2004

=head2 SYNOPSIS

This document gives a high level overview of the future of
the Perl DBI module.

The DBI module is the standard database interface for Perl applications.
It is used worldwide in countless applications, in every kind of
business, and on platforms from clustered super-computers to PDAs.
Database interface drivers are available for all common databases
and many not-so-common ones.

In the 10 years since the DBI was first released, incremental
development has continued at a reasonably steady pace. A growing
number of significant issues have, however, not been addressed by
this incremental development process.

The planned changes cover testing, performance, high availability
and load balancing, batch statements, Unicode, portability, and more.

Addressing these issues now, in coordinated way, will help ensure
maximum future functionality with minimal disruptive (incompatible)
upgrades.

=head2 SCOPE

Broad categories of changes are outlined here along with some rationale,
but implementation details and minor planned enhancements are omitted.
More details can be found in: L<http://svn.perl.org/modules/dbi/trunk/ToDo>


=head1 CHANGES AND ENHANCEMENTS

=head2 Batch Statements

Batch statements are a sequence of SQL statements, or a stored procedure
containing a sequence of SQL statements, which can be executed as a whole.

Currently the DBI has no standard interface for dealing with batch statements.
After considerable discussion, an interface design has been agreed upon with driver
authors, but has not yet been implemented.

This would enable greater application portability between databases,
and greater performance for databases that directly support batch statements.

=head2 Unicode

Use of Unicode with the DBI is growing rapidly. The DBI should do more
to help drivers support Unicode and help applications work with drivers
that don't yet support Unicode directly.

* Define expected behavior for fetching data and binding parameters.

* Fix 'leaking' of UTF8 flag from one row to the next.

* Provide interfaces to support Unicode issues for XS and pure Perl drivers
and applications.

This would smooth the transition to Unicode for many applications and drivers.


=head2 Testing

The DBI has a test suite. Every driver has a test suite.  Each is limited in
its scope.  The driver test suite is testing for behavior that the driver
author thinks the DBI specifies, but may be subtly incorrect.  These test
suites are poorly maintained because the return on investment for a single
driver is too low to provide sufficient incentive.

A common test suite that can be reused by all the drivers is needed.
It would:

* Ensure all drivers conform to the DBI specification.
Easing the porting applications between databases, and the implementation of
database independent modules layered over the DBI.

* Improve the DBI specification by clarifying unclear issues in order to
implement test cases.

* Improve the proportion of well tested code in the DBI and drivers.

* Encourage expansion of the test suite as driver authors and others will be
motivated by the greater benefits of their contributions.

* Detect and record optional functionality that a driver has not yet implemented.

* Improve the testing of DBI subclassing, DBI::PurePerl and the
various "transparent" drivers, such as DBD::Proxy and DBD::Multiplex,
by automatically running the test suite through them.


=head2 Performance

The DBI has always treated performance as a priority. Some parts of the
implementation, however, remain unoptimized, especially in relation to threads.

* When the DBI is used with a Perl built with thread support enabled
(such as for Apache mod_perl 2, and some common Linux distributions)
it runs significantly slower. There are two reasons for this and both
can be fixed but require non-trivial changes to both the DBI and drivers.

* Connection pooling in a threaded application, such as mod_perl, is
difficult because DBI handles cannot be passed between threads.
An alternative mechanism for passing connections between threads
has been defined, and an experimental connection pool module
implemented using it, but development has stalled.

* The majority of DBI handle creation code is implemented in Perl.
Moving most of this to C will speed up handle creation significantly.

* The popular fetchrow_hashref() method is many times slower than
fetchrow_arrayref(). It has to get the names of the columns, then create and
load a new hash each time. A $h->{FetchHashReuse} attribute would allow the
same hash to be reused each time making fetchrow_hashref() about the same speed
as fetchrow_arrayref().

* Support for asynchronous (non-blocking) DBI method calls would enable
applications to continue processing in parallel with database activity.
This is also relevant for GUI and other event-driven applications.
The DBI needs to define a standard interface for this so drivers can
implement it in a portable way, where possible.


=head2 Introspection

* The methods of the DBI API are installed dynamically when the DBI
is loaded.  The data structure used to define the methods and their
dispatch behavior should be made part of the DBI API. This would
enable more flexible and correct behavior by modules subclassing
the DBI and by dynamic drivers such as DBD::Proxy and DBD::Multiplex.

* Handle attribute information should also be
made available, for the same reasons.

* Currently is it not possible to discover all the child statement
handles that belong to a database handle (or all database handles
that belong to a driver handle).  This makes certain tasks more
difficult, especially some debugging scenarios.  A cache of
weak references to child handles would solve the problem without
creating reference loops.

* A DBI handle is a reference to a tied hash and so has an 'outer'
hash that the handle reference points to and an 'inner' hash holding
the DBI data.  By allowing the inner handle to be changed, for
example swapped with a different handle, many new behaviors become
possible. For example a database handle to a database that has crashed
could have its inner handle changed to a new connection to a replica.

* It is often useful to know which handle attributes have been changed
since the handle was created (e.g., in mod_perl where a handle needs
to be reset or cloned). This will become more important as developers
start exploring the ability to change the inner handle.


=head2 High Availability and Load Balancing

* The DBD::Multiplex driver provides a framework to enable a wide range of
dynamic functionality, including support for high-availability, load-balancing,
caching, and access to distributed data.  It is currently being rewritten to
greatly increase its flexibility and has potential to be a very powerful tool,
but development has stalled.

* The DBD::Proxy module is complex and relatively inefficient because
it's trying to be a complete proxy for most DBI method calls.  For many
applications a simpler proxy architecture that operates with a single
round-trip to the server would be sufficient and preferable.

New proxy client and server classes are needed, which could be subclassed to
support specific client to server transport mechanisms (such as HTTP and
Spread::Queue).

Apart from the efficiency gains, this would also enable the use of
a load-balanced pool of stateless servers.

* The DBI currently offers no support for distributed transactions.
The most useful elements of the standard XA distributed transaction interface
standard could be included in the DBI specification.  Drivers for databases
which support distributed transactions could then be extended to support it.


=head2 Extensibility

The DBI can be extended in three main dimensions: subclassing the
DBI, subclassing a driver, and callback hooks. Each has different
pros and cons and each is applicable in different situations.

* Subclassing the DBI is functional but not well defined and some
key elements are incomplete, particularly the DbTypeSubclass mechanism
(that automatically subclasses to a class tree according to the
type of database being used).  It also needs more thorough testing.

* Subclassing a driver is undocumented, poorly tested and very
probably incomplete. However it's a powerful way to embed certain
kinds of functionality 'below' applications while avoiding some of
the side-effects of subclassing the DBI (especially in relation to
error handling).

* Callbacks are currently limited to error handling (the HandleError
and HandleSetError attributes).  Providing callback hooks for more events, such
as a row being fetched, would enable utility modules, for example, to modify
the behavior of a handle independent of any subclassing in use.


=head2 Database Portability

* The DBI has not yet addressed the issue of portability among SQL
dialects.  This is the main hurdle limiting database portability
for DBI applications.

The goal is not to fully parse the SQL and rewrite it in a different
dialect.  That's well beyond the scope of the DBI and should be
left to layered modules.  A simple token rewriting mechanism
for five comment styles, two quoting styles, four placeholder styles,
plus the ODBC "{foo ...}" escape syntax is sufficient to significantly
raise the level of SQL portability.

* Another problem area is date/time formatting.  Since version 1.41
the DBI has defined a way to express that dates should be fetched in SQL
standard date format (YYYY-MM-DD).  This is one example of the more general
case where bind_col() needs to be called with particular attributes on all
columns of a particular type.

A mechanism is needed whereby an application can specify default bind_col()
attributes to be applied automatically for each column type. With a single step,
all DATE type columns, for example, can be set to be returned in the standard
format.


=head2 Debugability

* Enabling DBI trace output at a high level of detail causes a large volume of
output, much of it unrelated to the problem being investigated. More trace
output should be controlled by the new named-topic mechanism instead of the
trace level.

* Calls to XS functions (such as many DBI and driver methods) don't
normally appear in the call stack.  Optionally enabling that would
enable more useful diagnostics to be produced.

* Integration with the Perl debugger would make it simpler to perform
actions on a per-handle basis (such as breakpoint on execute,
breakpoint on error).


=head2 Other Enhancements

* Definition of an interface to support scrollable cursors.


=head2 Parrot and Perl 6

The current DBI implementation in C code is very unlikely to run on Perl 6.
Perl 6 will target the Parrot virtual machine and so the internal architecture
will be radically different from Perl 5.

One of the goals of the Parrot project is to be a platform for many dynamic
languages (including Python, PHP, Ruby, etc) and to enable those languages to
reuse each others modules. A database interface for Parrot is also a database
interface for any and all languages that run on Parrot.

The Perl DBI would make an excellent base for a Parrot database interface
because it has more functionality, and is more mature and extensible,
than the database interfaces of the other dynamic languages.

I plan to better define the API between the DBI and the drivers and
use that API as the primary API for the 'raw' Parrot database interface.
This project is known a Parrot DBDI (for "DataBase Driver Interface").
Here's the announcement:

  http://groups.google.com/groups?selm=20040127225639.GF38394@dansat.data-plan.com

The bulk of the work will be translating the DBI C and Perl base class
code into Parrot PIR, or a suitable language that generates PIR.
The project stalled, due to Parrot not having key functionality at the time.
That has been resolved but the project has not yet restarted.

Each language targeting Parrot would implement their own small
language-specific method dispatcher (a "Perl6 DBI", "Python DBI",
"PHP DBI" etc) layered over the common Parrot DBDI interface and drivers.

The major benefit of the DBDI project is that a much wider community
of developers share the same database drivers. There would be more
developers maintaining less code so the benefits of the Open Source
model are magnified.


=head1 PRIORITIES

The foundations of many of the changes described above require
changes to the interface between the DBI and drivers. To clearly
define the transition point, the source code will be forked into a
DBI v1 branch and the mainline bumped to v2.

DBI v1 will continue to be maintained for bug fixes and any
enhancements that ease the transition to DBI v2.

=head2 Transition Drivers

The first priority is to make all the infrastructure changes that
impact drivers and make an alpha release available that driver
authors can target. As far as possible, the changes will be implemented
in a way that enables driver authors use the same code base for DBI
v1 and DBI v2.

The main changes required by driver authors are:

* Code changes for PERL_NO_GET_CONTEXT, plus removing PERL_POLLUTE
and DBIS

* Code changes in DBI/DBD interface (new way to create handles, new
callbacks etc)

* Common test suite infrastructure (driver-specific test base class)

=head2 Transition Applications

A small set of incompatible changes that may impact some applications
will also be made in v2.0. See http://svn.perl.org/modules/dbi/trunk/ToDo

=head2 Incremental Developments

Once DBI v2.0 is available, the other enhancements can be implemented
incrementally on the updated foundations. Priorities for those
changes have not yet been set.

=head1 RESOURCES AND CONTRIBUTIONS

This roadmap does not address the resources required to implement
in a timely manner the changes for DBI v2.0 and beyond.
I am preparing a separate document to address those issues.

=cut
