use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

### how to render date values from database

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

my $stmt = qq(select id, title, date(last_modified, 'unixepoch') from recipe order by last_modified asc;);
my $sth = $dbh->prepare($stmt);

my ($id, $title, $lm) = $dbh->selectrow_array($sth);
print STDERR "Earliest modification date: $id, $title, $lm\n";

$stmt = qq(select id, title, date(last_modified, 'unixepoch') from recipe order by last_modified desc;);
$sth = $dbh->prepare($stmt);

$rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

($id, $title, $lm) = $dbh->selectrow_array($sth);
print STDERR "Last modification date: $id, $title, $lm\n";

$dbh->disconnect();
