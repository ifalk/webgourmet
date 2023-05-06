use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

### what are stored in db and how?

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

my $json = read_file('recipe_hash.json', { binmode => ':raw' });
my $recipe_hash = decode_json($json);

my $select_fields = qq(recipe_id,category);

my $stmt = qq(select $select_fields from categories;); 
my $sth = $dbh->prepare( $stmt);
my $rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

my $cat_hash = {};
my %db_categories = {};

while (my ($recipe_id, $category) = $sth->fetchrow()) {
  if ($category and exists $recipe_hash->{$recipe_id}) {
    $cat_hash->{$recipe_id}->{$category}++;
    $db_categories->{$category}->{$recipe_id}++;
  }
}

#### No longer need to access db, disconnect
$dbh->disconnect();

my $categories = {};

foreach my $id (keys %{ $cat_hash }) {
  if (exists $recipe_hash->{$id}) {
    my $cat_string = join(', ', keys %{ $cat_hash->{$id} });
    $recipe_hash->{$id}->{'category'} = $cat_string;
    $categories->{$cat_string}->{$id}++;
  }
}

foreach my $cat (sort keys %{ $categories }) {
  print STDERR "$cat\n";
}

is_deeply($db_categories, $categories, 'hashes should be the same');
# print STDERR Dumper($categories);
