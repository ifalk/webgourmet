use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $json = read_file('id2file_name.json', { binmode => ':raw' });
my $id2file_name = decode_json($json);

#### extract last modification date (of db)
use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

my $last_access = Local::Modulino::GourmetExport->get_last_access($dbh);
print STDERR "Last db access: $last_access\n";

$dbh->disconnect();


# use XML::LibXML;

# my $index_title = 
