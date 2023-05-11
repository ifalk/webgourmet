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
my $db_categories = {};

while (my ($recipe_id, $category) = $sth->fetchrow()) {
  if ($category) {
    $cat_hash->{$recipe_id}->{$category}++;
    $db_categories->{$category}->{$recipe_id}++;
   }
}

#### No longer need to access db, disconnect
$dbh->disconnect();

print STDERR "Recipes with more than one category:\n";
foreach my $recipe_id (keys %{ $cat_hash }) {
  if (scalar(keys %{ $cat_hash->{$recipe_id} }) > 1) {
    print STDERR "$recipe_id\n";
    print STDERR $recipe_hash->{$id}->{'category'}, "\n";
  }
}

print STDERR "\n\n\n";

foreach my $id (keys %{ $cat_hash }) {
  if (exists $recipe_hash->{$id}) {
    my $cat_string = join(', ', sort keys %{ $cat_hash->{$id} });
    $recipe_hash->{$id}->{'category'} = $cat_string;
  }
}


# print STDERR $recipe_hash->{1824}->{'category'}, "\n";

my $categories = {};

foreach my $id (keys %{ $recipe_hash }) {
  if ($recipe_hash->{$id}->{'category'}) {
    $categories->{$recipe_hash->{$id}->{'category'}}->{$id}++;
  }
}
foreach my $cat (sort keys %{ $categories }) {
  print STDERR "$cat+\n";
}

#### json file contains wrong categories:
##########################################

# $json = read_file('id2file_name.json', { binmode => ':raw' });
# my $id2file_name = decode_json($json);

# $categories = {};

# foreach my $id (keys %{ $id2file_name }) {
#   $categories->{$id2file_name->{$id}->{'category'}}->{$id}++;
# }

# foreach my $cat (sort keys %{ $categories }) {
#   print STDERR "$cat\n";
# }

#### recompute id2file_name

# my $id2file_name = {};

# foreach my $id (keys %{ $recipe_hash }) {

#   my $title = $recipe_hash->{$id}->{'title'};
#   $id2file_name->{$id}->{'title'} = $title;


#   $id2file_name->{$id}->{'rating'} = $recipe_hash->{$id}->{'rating'};

#   unless ($recipe_hash->{$id}->{'category'}) {
#     print STDERR "Recipe $id $title has no category\n";
#   };

#   $id2file_name->{$id}->{'category'} = $recipe_hash->{$id}->{'category'};

#   #### Where to save the html file to

#   #### only keep ascii and blancs in title string
#   my $title_sanitized = $title;
#   $title_sanitized =~ s{[^A-Za-z0-9 ]}{}g;

#   #### file name for links (in index file):
#   my $file_name = "$title_sanitized$id.html";

#   $id2file_name->{$id}->{'html_file_name'} = $file_name;
# };


my $id2file_name = Local::Modulino::GourmetExport->make_id2file_name($recipe_hash);

$categories = {};

foreach my $id (keys %{ $id2file_name }) {
  $categories->{$id2file_name->{$id}->{'category'}}->{$id}++;
}
print STDERR "-----\n";
foreach my $cat (sort keys %{ $categories }) {
  print STDERR "$cat+\n";
}
