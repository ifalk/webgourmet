use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

# my $json = read_file('recipe_hash.json', { binmode => ':raw' });
# my $recipe_hash = decode_json($json);

### are there empty recipe ids? No:

# foreach my $id ( sort keys %{ $recipe_hash } ) {
#   print STDERR "$id\n";
# }

### this is how id2file_name hash is built based on recipe_hash (containing categories)
### the weird categories appeared

# my $id2file_name = Local::Modulino::GourmetExport->make_id2file_name($recipe_hash);

#### Categories are wrong when computed like this:

# my $id2file_name = {};
# my $categories = {};

# foreach my $id (sort { $a <=> $b } keys %{ $recipe_hash }) {

#   if ($recipe_hash->{$id}->{'title'}) {
#     $title = $recipe_hash->{$id}->{'title'};
#     $id2file_name->{$id}->{'title'} = $title;
#   } else {
#     print STDERR "Recipe $id has no title\n";
#   }


#   if ($recipe_hash->{$id}->{'rating'}) {
#     $id2file_name->{$id}->{'rating'} = $recipe_hash->{$id}->{'rating'};
#   } else {
#     $id2file_name->{$id}->{'rating'} = '';
#   }

#   if ($recipe_hash->{$id}->{'category'}) {
#     my $category = $recipe_hash->{$id}->{'category'};
#     $id2file_name->{$id}->{'category'} = $category;
#     $categories->{$category}->{$id}++;
#   } else {
#     $id2file_name->{$id}->{'category'} = '';
#     print STDERR "Recipe $id has no category\n";
#   };

#   #### only keep ascii and blancs in title string
#   my $title_sanitized = $title;
#   $title_sanitized =~ s{[^A-Za-z0-9 ]}{}g;

#   #### file name for links (in index file):
#   my $file_name = "$title_sanitized$id.html";

#   $id2file_name->{$id}->{'html_file_name'} = $file_name;
  
# }

### what about categories in recipe hash? They are already wrong (at this point):

# my $categories = {};

# my @ids = keys %{ $recipe_hash };

# foreach my $id (@ids) {
#   # print STDERR Dumper($recipe_hash->{$id});

#   my $category = $recipe_hash->{$id}->{'category'};
#   $categories->{$category}->{$id}++;
# }

### build hash differently, don't add categories to existing hash

my $recipe_hash = Local::Modulino::GourmetExport->fetch_all_recipes($dbh);

#my $cat_hash = Local::Modulino::GourmetExport->fetch_all_categories($dbh);

### now add categories to recipe hash, now ok, tested if category exists in db query:
# foreach my $id (keys %{ $recipe_hash }) {
#   my $cat_string = '';
#   if (exists $cat_hash->{$id}) {
#     $cat_string = join(', ', keys %{ $cat_hash->{$id} });
#   } else {
#     print STDERR "No category for recipe id $id\n"
#   }
#   $recipe_hash->{$id}->{'category'} = $cat_string;
#   $categories->{$cat_string}->{$id}++;
# }

### add categories to recipe hash, now ok:

$recipe_hash = Local::Modulino::GourmetExport->fetch_all_categories($dbh, $recipe_hash);

foreach my $id (keys %{ $recipe_hash }) {
  if (exists $recipe_hash->{$id}->{'category'}) {
    my $category = $recipe_hash->{$id}->{'category'};
    $categories->{$category}->{$id}++;
  }
}

foreach my $cat (sort keys %{ $categories }) {
  print STDERR "$cat\n";
}
