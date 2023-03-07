use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );


use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';

my $last_access = Local::Modulino::DB2JSON->get_last_access($database);

print STDERR "Last access: $last_access\n";

