#!perl -w
use 5.005;
use ExtUtils::MakeMaker;
use strict;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
use Config;
my $svh = "$Config{archlibexp}/CORE/sv.h";
my $sv_table_file = "sv-table.inc";

{
    # Gah. MakeMaker in 5.6.2 (at least) is relying on $/;
    local $/;
    open FH, "<$svh" or die "Can't open $svh: $!";
    $_ = <FH>;
}

my ($enum) = /typedef\s+enum\s+{([^}]+)}\s+svtype;/s;
die "Can't parse $svh to find type enum ... svtype" unless defined $enum;

my @types;
my $count = 0;
while ($enum =~ m!SVt_(\w+),?\s+/\*\s+(\d+)\s+\*/!g) {
    die "enum parsing in $svh out of sync -- $count != $2" unless $count == $2;
    $types[$count] = $1;
    $count++;
}
die "Only found " . scalar (@types) . ", expected 16 or more" if @types < 16;

open FH, ">$sv_table_file" or die "Can't open $sv_table_file: $!";
print FH "const char *sv_names[] = {\n";
while (my $type = shift @types) {
    print FH qq{  "$type"};
    print FH "," if @types;
    print FH "\n";
}
print FH "};\n";
print FH "const size_t sv_names_len = sizeof(sv_names) / sizeof(char *);\n";
close FH or die "Can't close $sv_table_file: $!";

WriteMakefile(
    NAME              => 'Devel::Arena',
    VERSION_FROM      => 'lib/Devel/Arena.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Devel/Arena.pm', # retrieve abstract from module
       AUTHOR         => 'Nicholas Clark <nick@talking.bollo.cx>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
    realclean => {FILES=> $sv_table_file},
);
