use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

### check how to render ratings from database

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my $stmt = qq(select distinct rating from recipe;);
my $sth = $dbh->prepare($stmt);

my $rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

print STDERR "Distinct ratings:\n";
while (my ($db_rating) = $sth->fetchrow()) {
  print STDERR Local::Modulino::DB2JSON->stringify_db_rating($db_rating), "\n";
}


$dbh->disconnect();

