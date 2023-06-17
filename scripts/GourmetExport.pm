#!/usr/bin/perl
package Local::Modulino::GourmetExport;

__PACKAGE__->run( @ARGV ) unless caller();

use warnings;
use strict;
use English;

use Data::Types qw(:all);
use List::MoreUtils qw(each_array);

use XML::LibXML;

use Data::Dumper;
use Carp;
use Carp::Assert;

use Pod::Usage;
use Getopt::Long;

use utf8;

=head1 NAME

perl db2json.pl 

=head1 USAGE

   perl db2json.pl recipes.db

=head1 DESCRIPTION

Reads gourmet recipe db (sqlite) and produces a json data structure, written to STDOUT

=head1 REQUIRED ARGUMENTS

The recipe db

=head1 OPTIONS

=cut

binmode(STDERR, 'encoding(UTF-8)');
#binmode(STDOUT, 'encoding(UTF-8)');

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

use JSON;

use strict;

sub run
{

  unless (@ARGV) { pod2usage(2) }; 

  my $database = $ARGV[0];

  my $class = shift;

  my $dbh = $class->get_db_handle($database);

  my $some_recipe_ids = [ qw(246 1122 1302) ];

  my $sth = $class-> fetch_some_ingredients($dbh, $some_recipe_ids);

  my $recipes_ing = $class->handle_ingredients($sth);

  print STDERR Dumper($recipes_ing);
}

sub get_db_handle
{


  my $class = shift;
  my $database = shift;

  my $driver = "SQLite";
  my $dsn = "DBI:$driver:dbname=$database";
  my $userid = "";
  my $password = "";
  my $dbh = DBI->connect($dsn, $userid, $password, { 
    RaiseError => 1,
    sqlite_open_flags => SQLITE_OPEN_READONLY,
    sqlite_unicode => 1, 
			 })
    or die $DBI::errstr;

  print STDERR "Opened database successfully\n";

  return $dbh;
}

sub get_number_of_recipes
{
  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select count(id) from recipe where deleted = 0);
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $result = $sth->fetchall_arrayref();
  my $nbr_recipes = $result->[0]->[0];
  return $nbr_recipes;
}

sub get_max_id
{
  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select max(id) from recipe);
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $result = $sth->fetchall_arrayref();
  my $max_id = $result->[0]->[0];
  return $max_id;
}

sub get_last_access
{
  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select date(last_access, 'unixepoch') from info;);
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $result = $sth->fetchall_arrayref();

  my $last_access = $result->[0]->[0];
  return $last_access;
}

sub get_recipes_involved
  #### returns additional involved recipes
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;

  my $recipe_id_string = join(', ', @{ $recipe_ids });

  my %recipe_hash;
  foreach my $id (@{ $recipe_ids }) {
    $recipe_hash{$id}++;
  }
  
  my $stmt = qq(select recipe_id,refid from ingredients where recipe_id in ($recipe_id_string) and deleted=0 and refid is not null;);

  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $recipes_found = [];
  my $more_recipes = 1;
  while ($more_recipes) {
    my %more_recipes_found;
    while (my ($recipe_id, $refid) = $sth->fetchrow()) {
      unless ($recipe_hash{$refid}) {
	$more_recipes_found{$refid}++;
	$recipe_hash{$refid}++;
	push(@{ $recipes_found }, $refid);
      }
    }

    if (%more_recipes_found) {
      my $more_recipes = $class->get_recipes_involved($dbh, $recipes_found);
      foreach my $rid (@{ $more_recipes }) {
	unless ($recipe_hash{$rid}) { push(@{ $recipes_found }, $rid); };
	$recipe_hash{$rid}++;
      }	
    } else {
      $more_recipes=0;
    }	

  }
  return $recipes_found;
}

sub fetch_some_ingredients
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;
  my $recipe_hash = shift; # needed to find out titles of referred to recipes (for html exports)

# get ingredients and build id -> ingredient hash

  my $recipe_id_string = join(', ', @{ $recipe_ids });

  my $select_fields = qq(recipe_id,refid,unit,amount,rangeamount,item,ingkey,optional,inggroup);

  my $stmt = qq(select $select_fields from ingredients where recipe_id in ($recipe_id_string) and deleted=0;); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $ing_hash = {};

  while (my $ing_list = $sth->fetchrow_hashref()) {

    my $recipe_id = $ing_list->{recipe_id};

    my $item = $ing_list->{item};

    my $unit = $ing_list->{unit};
    my $amount = $class->stringify_amounts($ing_list->{amount}, $ing_list->{rangeamount});
    my $optional = $ing_list->{optional};
    my $ingkey = $ing_list->{ingkey};

    my $ing_group = $ing_list->{inggroup};
    unless ($ing_group) {
      $ing_group = 'none';
    }

    my %fields = (
      'unit' => $unit,
      'amount' => $amount,
      'optional' => $optional,
      'ingkey' => $ingkey
    );

    my $item_hash;

    while ( my ($key, $value) = each(%fields) ) {
      # $ing_hash->{$recipe_id}->{$ing_group}->{$item}->{$key} = $value;
      $item_hash->{$key} = $value;
    };

    if ($unit and ($unit eq 'recipe')) {
      my $refid = $ing_list->{'refid'};
      if ($recipe_hash and $recipe_hash->{$refid}) {
	my $reftitle = $recipe_hash->{$refid}->{'title'};
	$refid = "$reftitle$refid.html";
      }
      # $ing_hash->{$recipe_id}->{$ing_group}->{$item}->{refid} = $ing_list->{refid};
      $item_hash->{'refid'} = $refid;
    }

    push(@{ $ing_hash->{$recipe_id}->{$ing_group} }, [ $item => $item_hash ]);
  }

  return $ing_hash;
}

sub fetch_all_ingredients
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_hash = shift; # needed to find out titles of referred to recipes (for html exports)

# get ingredients and build id -> ingredient hash

  my $select_fields = qq(recipe_id,refid,unit,amount,rangeamount,item,ingkey,optional,inggroup);

  my $stmt = qq(select $select_fields from ingredients where deleted=0;); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $ing_hash = {};

  while (my $ing_list = $sth->fetchrow_hashref()) {

    my $recipe_id = $ing_list->{recipe_id};

    my $item = $ing_list->{item};

    my $unit = $ing_list->{unit};
    my $amount = $class->stringify_amounts($ing_list->{amount}, $ing_list->{rangeamount});
    my $optional = $ing_list->{optional};
    my $ingkey = $ing_list->{ingkey};

    my $ing_group = $ing_list->{inggroup};
    unless ($ing_group) {
      $ing_group = 'none';
    }

    my %fields = (
      'unit' => $unit,
      'amount' => $amount,
      'optional' => $optional,
      'ingkey' => $ingkey
    );

    my $item_hash;

    while ( my ($key, $value) = each(%fields) ) {
      # $ing_hash->{$recipe_id}->{$ing_group}->{$item}->{$key} = $value;
      $item_hash->{$key} = $value;
    };

    if ($unit and ($unit eq 'recipe')) {
      my $refid = $ing_list->{'refid'};
      if ($recipe_hash and $recipe_hash->{$refid}) {
	my $reftitle = $recipe_hash->{$refid}->{'title'};
	my $title_sanitized = $reftitle;
	$title_sanitized =~ s{[^A-Za-z0-9 ]}{}g;
	$refid = "$title_sanitized$refid.html";
      }
      # $ing_hash->{$recipe_id}->{$ing_group}->{$item}->{refid} = $ing_list->{refid};
      $item_hash->{'refid'} = $refid;
    }

    push(@{ $ing_hash->{$recipe_id}->{$ing_group} }, [ $item => $item_hash ]);
  }

  return $ing_hash;
}



sub fetch_ingredients
{
  my $class = shift;
  my $dbh = shift;

# get ingredients and build id -> ingredient hash

  my $ing_stmt = qq(select * from ingredients); 
  my $ing_sth = $dbh->prepare( $ing_stmt);
  my $rv = $ing_sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $ing_sth;
}

sub fetch_amounts
{

  # fetch distinct amounts in ingredient table (for testing)

  my $class = shift;
  my $dbh = shift;


  my $stmt = qq(select distinct amount from ingredients); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

}

sub fetch_images
{
  # fetch images (for testing)

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select id, image, thumb from recipe where deleted=0);
  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;
}

sub fetch_inggroups
{
  # fetch inggroups

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select distinct inggroup from ingredients); 

  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

};

sub fetch_recipes_wo_inggroup
{
  # fetch inggroups

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select distinct recipe_id from ingredients where inggroup is null or inggroup = '';); 

  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

};

sub fetch_units
{
  # fetch units

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select distinct unit from ingredients); 

  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

};


sub fetch_recipes_wo_unit
{
  # fetch units

  my $class = shift;
  my $dbh = shift;

  my $stmt = qq(select distinct recipe_id from ingredients where unit is null or unit = '';); 

  my $sth = $dbh->prepare($stmt);

  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  return $sth;

};

sub fetch_some_recipes
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;

# get recipe description and build id -> description hash

  my $recipe_id_string = join(', ', @{ $recipe_ids });
  my $select_fields = qq(id,title,instructions,modifications,cuisine,rating,source,strftime('%H:%M', preptime, 'unixepoch'),strftime('%H:%M', cooktime, 'unixepoch'),servings,link,date(last_modified, 'unixepoch'),yields,yield_unit,image);
  my @col_names = qw(title instructions modifications cuisine rating source preptime cooktime servings link last_modified yields yield_unit image);
  my $stmt = qq(select $select_fields  from recipe where id in ($recipe_id_string) and deleted=0;); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $recipe_hash = {};

  while (my @col_values = $sth->fetchrow()) {
    my $id = shift(@col_values); # remove value for 'id'

    my $col_hash={};
    my $ea = each_array(@col_names, @col_values);
    while (my ($col_name, $col_value) = $ea->()) {
      $col_hash->{$col_name} = $col_value;
    }

    ### these fields are just copied
    foreach my $col_name (qw(title instructions modifications cuisine last_modified)) {
      $recipe_hash->{$id}->{$col_name} = $col_hash->{$col_name};
    }

    ### strings for times
    foreach my $time (qw(preptime cooktime)) {
      $recipe_hash->{$id}->{$time} = $class->stringify_db_time($col_hash->{$time});
    }


    ### strings for yields
    $recipe_hash->{$id}->{yields} = $class->stringify_yields($col_hash->{servings}, $col_hash->{yields}, $col_hash->{yield_unit});

    ### string for rating
    $recipe_hash->{$id}->{rating} = $class->stringify_db_rating($col_hash->{rating});

    ### strings for source and link
    my ($source, $link) = $class->stringify_source_link($col_hash->{source}, $col_hash->{link});
    $recipe_hash->{$id}->{source} = $source;
    $recipe_hash->{$id}->{link} = $link;
    
  }
  
  return $recipe_hash;
}

sub fetch_all_recipes
{
  my $class = shift;
  my $dbh = shift;

# get recipe description and build id -> description hash

  my $select_fields = qq(id,title,instructions,modifications,cuisine,rating,source,strftime('%H:%M', preptime, 'unixepoch'),strftime('%H:%M', cooktime, 'unixepoch'),servings,link,date(last_modified, 'unixepoch'),yields,yield_unit,image);
  my @col_names = qw(title instructions modifications cuisine rating source preptime cooktime servings link last_modified yields yield_unit image);
  my $stmt = qq(select $select_fields  from recipe where deleted=0;); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $recipe_hash = {};

  while (my @col_values = $sth->fetchrow()) {
    my $id = shift(@col_values); # remove value for 'id'

    my $col_hash={};
    my $ea = each_array(@col_names, @col_values);
    while (my ($col_name, $col_value) = $ea->()) {
      $col_hash->{$col_name} = $col_value;
    }

    ### these fields are just copied
    foreach my $col_name (qw(title instructions modifications cuisine last_modified)) {
      $recipe_hash->{$id}->{$col_name} = $col_hash->{$col_name};
    }

    ### strings for times
    foreach my $time (qw(preptime cooktime)) {
      $recipe_hash->{$id}->{$time} = $class->stringify_db_time($col_hash->{$time});
    }


    ### strings for yields
    $recipe_hash->{$id}->{yields} = $class->stringify_yields($col_hash->{servings}, $col_hash->{yields}, $col_hash->{yield_unit});

    ### string for rating
    $recipe_hash->{$id}->{rating} = $class->stringify_db_rating($col_hash->{rating});

    ### strings for source and link
    my ($source, $link) = $class->stringify_source_link($col_hash->{source}, $col_hash->{link});
    $recipe_hash->{$id}->{source} = $source;
    $recipe_hash->{$id}->{link} = $link;
    
  }
  
  return $recipe_hash;
}


sub fetch_some_categories
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;
  my $recipe_hash = shift;

  # get categories and build id -> categories hash

  my $recipe_id_string = join(', ', @{ $recipe_ids });

  my $select_fields = qq(recipe_id,category);

  my $stmt = qq(select $select_fields from categories where recipe_id in ($recipe_id_string)); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $cat_hash = {};

  while (my ($recipe_id, $category) = $sth->fetchrow()) {
    $cat_hash->{$recipe_id}->{$category}++;
  }

  ### if recipe hash is given update it with categories and return it
  if ($recipe_hash) {
    foreach my $id (keys %{ $cat_hash }) {
      my $cat_string = join(', ', keys %{ $cat_hash->{$id} });
      $recipe_hash->{$id}->{'category'} = $cat_string;
    }
    return $recipe_hash;
  }
  
  return $cat_hash;
  
}

sub fetch_all_categories
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_hash = shift;

  # get categories and build id -> categories hash

  my $select_fields = qq(recipe_id,category);

  my $stmt = qq(select $select_fields from categories;); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }

  my $cat_hash = {};

  while (my ($recipe_id, $category) = $sth->fetchrow()) {
    if ($category) {
      $cat_hash->{$recipe_id}->{$category}++;
    }
  }

  ### if recipe hash is given update it with categories and return it
  if ($recipe_hash) {
    foreach my $id (keys %{ $cat_hash }) {
      if (exists $recipe_hash->{$id}) {
        my $cat_string = join(', ', keys %{ $cat_hash->{$id} });
	$recipe_hash->{$id}->{'category'} = $cat_string;
      }
    }
    return $recipe_hash;
  }
  
  return $cat_hash;
  
}

sub recipes_wo_cat
  ### check which recipes don't have a category
{
  my $class = shift;
  my $recipe_hash = shift;

  my $recipes_wo_cat = {};

  unless ($recipe_hash) { return $recipes_wo_cat };

  foreach my $id (keys %{ $recipe_hash }) {
    unless (exists $recipe_hash->{$id}->{'category'}) {
      $recipes_wo_cat->{$id}++;
    }
  }
  return $recipes_wo_cat;
}

sub fetch_some_images
  ### gets images for given ids from database
  ### saves them as pic_dir/id.jpg
  ### returns a reference to a hash: id -> saved image file
  ### parameters
  ### 1. database handle
  ### 2. recipe ids for which to get images (array ref)
  ### 3. optional: pic_dir, directory where to save images (created if it doesn't exist
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_ids = shift;
  my $pic_dir = shift;


  croak 'Need recipe ids (2nd par) for this function' unless $recipe_ids;
  unless ($pic_dir) {
    $pic_dir = 'pics';
  }
  
  
  my $recipe_id_string = join(', ', @{ $recipe_ids });

  my $select_fields = qq(id,image);

  my $stmt = qq(select $select_fields from recipe where id in ($recipe_id_string)); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }



  my %id2image;

  while (my ($id, $img) = $sth->fetchrow()) {
    if ($img) {
      $id2image{$id} = $img;
    }
  }

  my $img_nbr = scalar(keys %id2image);

  my $id2img_file = {};
  unless ($img_nbr) { return $id2img_file };

  use File::Path qw(make_path);
  eval { make_path($pic_dir) };
  if ($@) {
    die "Couldn't create $pic_dir: $@";
  }

  foreach my $id (keys %id2image) {
    my $img_file = "$pic_dir/$id.jpg";
    open my $fh, '>', $img_file or die $!;
    binmode $fh;
    print $fh $id2image{$id};
    close $fh;

    $id2img_file->{$id} = $img_file;
  }

  return $id2img_file;
}

sub fetch_all_images
  ### gets images for all recipes from database
  ### saves them as pic_dir/id.jpg
  ### returns a reference to a hash: id -> saved image file
  ### parameters
  ### 1. database handle
  ### 2. optional: pic_dir, directory where to save images (created if it doesn't exist
{
  my $class = shift;
  my $dbh = shift;
  my $pic_dir = shift;

  unless ($pic_dir) {
    $pic_dir = 'pics';
  }
  
  my $select_fields = qq(id,image);

  my $stmt = qq(select $select_fields from recipe where deleted=0); 
  my $sth = $dbh->prepare( $stmt);
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) {
    print $DBI::errstr;
  }



  my %id2image;

  while (my ($id, $img) = $sth->fetchrow()) {
    if ($img) {
      $id2image{$id} = $img;
    }
  }

  my $img_nbr = scalar(keys %id2image);

  my $id2img_file = {};
  unless ($img_nbr) { return $id2img_file };

  use File::Path qw(make_path);
  eval { make_path($pic_dir) };
  if ($@) {
    die "Couldn't create $pic_dir: $@";
  }

  foreach my $id (keys %id2image) {
    my $img_file = "$pic_dir/$id.jpg";
    open my $fh, '>', $img_file or die $!;
    binmode $fh;
    print $fh $id2image{$id};
    close $fh;

    $id2img_file->{$id} = $img_file;
  }

  return $id2img_file;
}


sub handle_ingredients
{
  my $class = shift;
  my $ing_sth = shift;
  my $recipes_ing = {};

  while (my $ing_list = $ing_sth->fetchrow_hashref()) {
    next if ($ing_list->{deleted});

    my $recipe_id = $ing_list->{recipe_id};

    my $item = $ing_list->{item};

    my $ing_group = $class->handle_inggroup($ing_list->{inggroup});
    
    my $unit = $class->handle_unit($ing_list->{unit});

    my $amount = $class->handle_amount($ing_list->{amount});

    my $optional = $class->handle_optional($ing_list->{optional});

    my %fields = (
      'unit' => $unit,
	'amount' => $amount,
	'optional' => $optional
    );


    while ( my ($key, $value) = each(%fields) ) {
      if ($recipes_ing->{$recipe_id}->{$ing_group}->{$item}->{$key}) {
	$recipes_ing->{$recipe_id}->{$ing_group}->{$item}->{$key} = $value;
      };
    };

    if ($unit and ($unit eq 'recipe')) {
      $recipes_ing->{$recipe_id}->{$ing_group}->{$item}->{refid} = $ing_list->{refid};
    }
  }


  return $recipes_ing;
};

sub stringify_amounts
{
  my $class = shift;
  my $db_amount = shift;
  my $db_rangeamount = shift;

  my $amount = $class->float_to_frac($db_amount, 0.02);
  my $rangeamount = $class->float_to_frac($db_rangeamount, 0.02);

  my $astring = $amount;

  if ($amount and $rangeamount) {
    my $join_string = '-';
    if ($db_rangeamount < $db_amount) {
      $join_string = ' ';
    }
    $astring = join($join_string, $amount, $rangeamount);
  }

  return $astring;
}

sub stringify_yields
{
  my $class = shift;
  my $db_servings = shift;
  my $db_yields = shift;
  my $yield_unit = shift;
  unless ($yield_unit) {
    $yield_unit = '';
  };

  my $servings = $class->float_to_frac($db_servings, 0.02);
  my $yields = $class->float_to_frac($db_yields, 0.02);

  my $yield_string = '';

  if ($servings) {
    $yield_string = "$servings servings";
  }

  unless ($yield_unit) {
    return $yields;
  }

  if ($yields) {
    $yield_string = join(' ', $yields, $yield_unit); 
  }

  return $yield_string;
}


sub float_to_frac {
  my $class = shift;
  my $n = shift;
  my $approx = shift;

  unless ($approx) {
    $approx = 0.01;
  }

  my %keep_divisors = (
    2 => 1,
    3 => 1,
    4 => 1,
    5 => 1,
    6 => 1,
    8 => 1,
    10 => 1,
    16 => 1
  );
  
  unless ($n) {
    return '';
  }

  if (is_whole($n)) {
    return $n;
  }
  
  my $i = int($n);
  my $rem = $n - $i;

  if ($rem and $rem<$approx) {
    return "$i";
  }
  
  my ($h, $k) = $class->fractify($rem, $approx);
  if ($keep_divisors{$k}) {
    if ($i) {
      return "$i $h/$k";
    }
    return "$h/$k";
  }

  my $rounded = sprintf("%.2f", $n);
  return $rounded;

}

sub fractify {
  my $class = shift;
  my $n = shift;
  my $approx = shift;

  if ($n eq '') { croak "number required\n"; }

  unless ($approx) {
    $approx = 0.01;
  }

  
  use Math::BigInt;
  use Math::BigRat;

  my $x = my $y = Math::BigRat->new($n)->babs();
  my $h = my $k1 = Math::BigInt->new(1);
  my $k = my $h1 = Math::BigInt->new(0);

  while (1) {
    my $t = $y->as_int();
    ($h, $h1) = ($t * $h + $h1, $h);
    ($k, $k1) = ($t * $k + $k1, $k);
    my $val = Math::BigRat->new($h, $k);
    my $err = $val - $x;
    # my $out = sprintf "%s: %s / %s = %.16g (%.1g)\n", $t, $h, $k, $val, $err;
    # print STDERR $out, "\n";
    last if (abs($err) < $approx);
    $y -= $t or last;
    $y = 1 / $y;
  }

  return ($h, $k);
}

sub stringify_db_time
{
  my $class = shift;

  ### db_time is a string as returned by strftime('%H:%M', ..., 'unixepoch');
  my $db_time = shift;


  my $tstring = '';

  unless ($db_time) { return $tstring; };

  my ($db_hours, $db_minutes) = split(':', $db_time);

  my $hours = $db_hours =~ s{^0+}{}r;
  my $min = $db_minutes =~ s{^0+}{}r;

  # print STDERR "db hours: $db_hours, converted: $hours\n";
  # print STDERR "db_min: $db_minutes, converted: $min\n";

  unless ($hours) {
    if ($min) {
      return "$min min";
    } else {
      return '';
    }
  }


  $tstring = "$hours h";

  unless ($min) {
    return $tstring;
  }

  return "$tstring $min min";
  
}

sub stringify_db_rating
{
  my $class = shift;

  ### db_rating  is an integer, which is null or at least 1 and at most 10.
  
  my $db_rating = shift;


  my $rstring = '';

  unless ($db_rating) { return $rstring; };
  if ($db_rating > 10) { return '' }; # rating not valid

  $rstring = $db_rating / 2;
  return "$rstring/5 Sterne";
}

sub stringify_source_link
{
  my $class = shift;

  ### 
  my $db_source = shift;
  my $db_link = shift;

  my $sstring = '';
  my $lstring = '';

  unless ($db_source or $db_link) {
    return ($sstring, $lstring);
  }

  unless ($db_source) {
    return ($sstring, "$db_link");
  }

  if ($db_link) {
    $lstring = "$db_link";
  }

  if ($db_source =~ m/^http/) {
    if ($db_link) {
      if ("$db_source" eq "$db_link") {
	return ('', $lstring);
      } else {
	return ("$db_source", $lstring);
      }
    } else {
      return ("$db_source", "$db_source");
    }
  } else {
    return ("$db_source", "$lstring"); 
  }

}

sub ingredient_subgroup_2_html
  #### build html ul Element for ingredient subgroup
  #### return this ul Element
{
  my $class = shift;
  my $ingredient_hash = shift;
  my $id = shift;
  my $subgroup = shift; # default = 'none'
  my $doc = shift;

  unless ($ingredient_hash) { croak "Argument missing: ingredient hash\n" };
  unless ($id) { croak "Argument missing: recipe id\n" };
  unless ($subgroup) { $subgroup = 'none' };
  unless ($doc) { croak "Argument missing: html document element (needed to create ul)\n" };

  my $ing_ref = $ingredient_hash->{$id};
  unless ($ing_ref->{$subgroup}) {
    die "There is no subgroup $subgroup for id $id\n";
  }

  my $ul = $doc->createElement('ul');
  $ul->setAttribute('class', 'ing');

  my %li_att_name_value = (
    'class' => 'ing',
    'itemprop' => 'ingredients'
    );


  foreach my $ing (@{ $ing_ref->{$subgroup} }) {
    my ($ing_name, $ing_atts) = @{ $ing };

    my @comp;
    foreach my $att (qw(amount unit)) {
      my $att_value = '';
      if ($ing_atts->{$att}) {
	$att_value = $ing_atts->{$att};
      }
      push(@comp, $att_value);
    }
    # my @comp = @{ $ing_atts }{ qw(amount unit) };

    my $ing_string = join(' ', @comp, $ing_name);
    if ($ing_atts->{'optional'}) {
      $ing_string = "$ing_string (optional)";
    }
    my $li = $doc->createElement('li');
    foreach my $att_name (keys %li_att_name_value) {
      $li->setAttribute($att_name, $li_att_name_value{$att_name});
    }
    if ($comp[1] eq 'recipe') {
      my $a = $doc->createElement('a');
      $a->setAttribute('target', '_blank');
      $a->setAttribute('rel', 'noopener noreferrer');

      $a->setAttribute('href', $ing_atts->{'refid'});
      $a->appendText($ing_string);
      $li->appendChild($a);
    } else {
      $li->appendText($ing_string);
    }
    $ul->appendChild($li);
  }
  
  return $ul;
}

sub setup_html_header
  ### sets up html header
  ### needed for header:
  ###      - recipe title
  ###      - link to stylesheet: style.css
  ### returns document element and html element
{
  my $class = shift;
  my $title = shift;

  my $version = '1.0';
  my $encoding = 'utf-8';
  my $doc = XML::LibXML::Document->new( $version, $encoding );

  my $rootnode = 'html';
  my $public = '-//W3C//DTD XHTML 1.0 Strict//EN';
  my $system = 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd';
  my $dtd = $doc->createInternalSubset( $rootnode, $public, $system);

  my $html = $doc->createElementNS('http://www.w3.org/1999/xhtml', 'html');

  my $head = $doc->createElement('head');

  my $meta = $doc->createElement('meta');
  $meta->setAttribute('http-equiv', 'content-type');
  $meta->setAttribute('content', 'text/html; charset=utf-8');
  $head->appendChild($meta);

  $head->appendTextChild('title', $title);

  my $css_link = $doc->createElement('link');
  $css_link->setAttribute('rel', 'stylesheet');
  $css_link->setAttribute('href', 'style.css');
  $css_link->setAttribute('type', 'text/css');
  $head->appendChild($css_link);

  $html->appendChild($head);

  return ($doc, $html);
  
};

sub make_html_recipe_description
  ### recipe header/description
  ### arguments (required)
  ###    - document element
  ###    - recipe hash containing data for recipe header
  ###    - recipe id
  ### arguments (optional)
  ###    - max recipe id - if present displayed in the recipe description
  ### returns a div element containing the recipe header/description
  ###
  ### Images are expected to be found in the 'pics' directory relative
  ### to where the html file is. Their file name is id.jpg
{
  my $class = shift;
  my $doc = shift;
  my $recipe_hash = shift;
  my $id = shift;
  my $max_rid = shift;

  unless ($doc) { croak "Argument 1 missing: document element\n" };
  unless ($recipe_hash) { croak "Argument 2 missing: recipe hash\n" };
  unless ($id) { croak "Argument 3 missing: recipe id\n"};

  my $rel_picdir = 'pics';

  my $r_div = $doc->createElement('div');
  $r_div->setAttribute('class', 'recipe');
  $r_div->setAttribute('itemscope');
  $r_div->setAttribute('itemtype', 'http://schema.org/Recipe');

  if ($recipe_hash->{$id}->{'image_file'}) {
    my $img = $doc->createElement('img');
    $img->setAttribute('src', "$rel_picdir/$id.jpg");
    $img->setAttribute('itemprop', 'image');
    $r_div->appendChild($img);
  }  

  my $div = $doc->createElement('div');
  $div->setAttribute('class', 'header');

  my $p = $doc->createElement('p');
  $p->setAttribute('class', 'title');

  my $span = $doc->createElement('span');
  $span->setAttribute('class', 'label');
  $span->appendText('Titel:');
  $p->appendChild($span);

  my $title = $recipe_hash->{$id}->{'title'};
  $span = $doc->createElement('span');
  $span->setAttribute('itemprop', 'name');
  $span->appendText($title);
  $p->appendChild($span);

  $div->appendChild($p);

  my %cols2labels = (
    'yields' => 'Ertrag',
    'cooktime' => 'Garzeit',
    'preptime' => 'Zubereitungszeit',
    'category' => 'Kategorie',
    'cuisine' => 'Küche',
    'source' => 'Quelle',
    'last_modified' => 'Letzte Änderung',
    'recipe_id' => 'Rezept Nr.',
    );

  my %cols2itemprops = (
    'yields' => 'recipeYield',
    'cooktime' => 'cookTime',
    'preptime' => 'prepTime',
    'category' => 'recipeCategory',
    'cuisine' => 'recipeCuisine',
    );

  foreach my $col (qw(yields cooktime preptime category cuisine)) {
    if ($recipe_hash->{$id}->{$col}) {
      my $p = $doc->createElement('p');
      $p->setAttribute('class', $col);
      my $span = $doc->createElement('span');
      $span->setAttribute('class', 'label');
      $span->appendText("$cols2labels{$col}:");
      $p->appendChild($span);
      
      $span = $doc->createElement('span');
      $span->setAttribute('itemprop', $cols2itemprops{$col});
      $span->appendText($recipe_hash->{$id}->{$col});
      $p->appendChild($span);

      $div->appendChild($p);
    }
  }

  if ($recipe_hash->{$id}->{'source'}) {
    $p = $doc->createElement('p');
    $p->setAttribute('class', 'source');
    $span = $doc->createElement('span');
    $span->setAttribute('class', 'label');
    $span->appendText("$cols2labels{'source'}:");
    $p->appendChild($span);
    $p->appendText(" $recipe_hash->{$id}->{'source'}");

    $div->appendChild($p);
  }

  if (my $link = $recipe_hash->{$id}->{'link'}) {
    $a = $doc->createElement('a');
    $a->setAttribute('href', $link);
    $a->setAttribute('target', '_blank');
    $a->appendText("Originalseite: $link");

    $div->appendChild($a);
  }

  if ($recipe_hash->{$id}->{'last_modified'}) {
    $p = $doc->createElement('p');
    $p->setAttribute('class', 'last_modified');
    $span = $doc->createElement('span');
    $span->setAttribute('class', 'label');
    $span->appendText("$cols2labels{'last_modified'}:");
    $p->appendChild($span);
    $p->appendText(" $recipe_hash->{$id}->{'last_modified'}");

    $div->appendChild($p);
  }

  $p = $doc->createElement('p');
  $p->setAttribute('class', 'recipe_id');
  $span = $doc->createElement('span');
  $span->setAttribute('class', 'label');
  $span->appendText("$cols2labels{'recipe_id'}:");
  $p->appendChild($span);
  my $text = " $id";
  if ($max_rid) {
    $text = "$text (max $max_rid)";
  }
  $p->appendText($text);

  $div->appendChild($p);


  $r_div->appendChild($div);

  return $r_div;
}

sub make_html_recipe_ingredients
  ### make html element containing ingredients
  ### arguments (required)
  ###     - document element
  ###     - div element - to which ingredient elements are to be appended
  ###     - ingredient hash
  ###     - recipe id
  ### returns
  ###    div element - with added ingredient elements
{
  my $class = shift;
  my $doc = shift;
  my $r_div = shift;
  my $ingredient_hash = shift;
  my $id = shift;

  unless ($doc) { croak 'Argument missing: html document element' };
  unless ($r_div) { croak 'Argument missing: recipe div element' };
  unless ($ingredient_hash) { croak 'Argument missing: ingredient hash' };
  unless ($id) { croak 'Argument missing: recipe id' };

  if ($ingredient_hash->{$id}) {

    my $ing_div = $doc->createElement('div');
    $ing_div->setAttribute('class', 'ing');

    my $h = $doc->createElement('h3');
    $h->appendText('Zutaten');
    $ing_div->appendChild($h);


    my $ing_ref = $ingredient_hash->{$id};
    # print STDERR Dumper($ing_ref);


    my $ul; 
    if ($ing_ref->{'none'}) {
      $ul = $class->ingredient_subgroup_2_html($ingredient_hash, $id, 'none', $doc);
      delete( $ing_ref->{'none'} );
    } else {
      $ul = $doc->createElement('ul');
      $ul->setAttribute('class', 'ing');
    }

    foreach my $subgroup (keys %{ $ing_ref }) {
      
      my $li = $doc->createElement('li');
      $li->setAttribute('class', 'inggroup');
      $li->appendText("$subgroup:");
      
      my $sub_ul = $class->ingredient_subgroup_2_html($ingredient_hash, $id, $subgroup, $doc);
      $li->appendChild($sub_ul);

      $ul->appendChild($li);
    }
    

    $ing_div->appendChild($ul);

    $r_div->appendChild($ing_div);

    
  }
  
  return $r_div;

}

sub make_html_recipe_instructions
  ### make html element containing instructions
  ### arguments (required)
  ###     - document element
  ###     - div element - to which instruction elements are to be appended
  ###     - recipe hash
  ###     - recipe id
  ### returns
  ###    div element - with added instruction elements
{
  my $class = shift;
  my $doc = shift;
  my $r_div = shift;
  my $recipe_hash = shift;
  my $id = shift;

  unless ($doc) { croak 'Argument missing: html document element' };
  unless ($r_div) { croak 'Argument missing: recipe div element' };
  unless ($recipe_hash) { croak 'Argument missing: recipe hash' };
  unless ($id) { croak 'Argument missing: recipe id' };

  if ($recipe_hash->{$id}->{'instructions'}) {

    my $div = $doc->createElement('div');
    $div->setAttribute('class', 'instructions');

    my $h3 = $doc->createElement('h3');
    $h3->appendText('Anweisungen');
    $div->appendChild($h3);
    
    my $ins_div = $doc->createElement('div');
    $ins_div->setAttribute('itemprop', 'recipeInstructions');

    ## split on linux or windows newline chars in string:
    my @ins_lines = split(/\r?\n/, $recipe_hash->{$id}->{'instructions'});

    foreach my $line (@ins_lines) {
      my $p = $doc->createElement('p');
      $p->appendText($line);
      $ins_div->appendChild($p);
    }
    $div->appendChild($ins_div);

    $r_div->appendChild($div);
  }

  return $r_div;
}

sub make_html_recipe_modifications
  ### make html element containing modifications
  ### arguments (required)
  ###     - document element
  ###     - div element - to which modifications elements are to be appended
  ###     - recipe hash
  ###     - recipe id
  ### returns
  ###    div element - with added modification elements
{
  my $class = shift;
  my $doc = shift;
  my $r_div = shift;
  my $recipe_hash = shift;
  my $id = shift;

  unless ($doc) { croak 'Argument missing: html document element' };
  unless ($r_div) { croak 'Argument missing: recipe div element' };
  unless ($recipe_hash) { croak 'Argument missing: recipe hash' };
  unless ($id) { croak 'Argument missing: recipe id' };

  if ($recipe_hash->{$id}->{'modifications'}) {

    my $div = $doc->createElement('div');
    $div->setAttribute('class', 'modifications');

    my $h3 = $doc->createElement('h3');
    $h3->appendText('Notizen');
    $div->appendChild($h3);
    
    ## split on linux or windows newline chars in string:
    my @lines = split(/\r?\n/, $recipe_hash->{$id}->{'modifications'});

    foreach my $line (@lines) {
      my $p = $doc->createElement('p');
      $p->appendText($line);
      $div->appendChild($p);
    }

    $r_div->appendChild($div);
  }

  return $r_div;
}

sub export2html_collect_data
  ### collect data needed for html export for given ids
  ### arguments (required)
  ###     - database handle
  ###     - list of ids (array reference)
  ### returns two hashes
  ###    - recipe hash: contains data about recipe description,
  ###                   instructions, modifications
  ###    - ingredient hash: contains data about ingredients
{
  my $class = shift;
  my $dbh = shift;
  my $ids = shift;

  unless ($dbh) { croak 'Argument missing: database handle' };
  unless ($ids) { croak 'Argument missing: list of ids (reference to array)' };

  my $add_recipes_needed = $class->get_recipes_involved($dbh, $ids);
  push (@{ $ids }, @{ $add_recipes_needed });
  print STDERR "All recipes needed: ", join(', ', @{ $ids }), "\n";

  my $recipe_hash = $class->fetch_some_recipes($dbh, $ids);
  # print STDERR Dumper($recipe_hash);

  my $ingredient_hash = $class->fetch_some_ingredients($dbh, $ids, $recipe_hash);

  #### add categories to recipe hash
  $recipe_hash = $class->fetch_some_categories($dbh, $ids, $recipe_hash);
  
  return ($recipe_hash, $ingredient_hash);
  
}

sub export_all_2html_collect_data
  ### collect data needed for html export for all recipes
  ### arguments (required)
  ###     - database handle
  ### returns two hashes
  ###    - recipe hash: contains data about recipe description,
  ###                   instructions, modifications
  ###    - ingredient hash: contains data about ingredients
{
  my $class = shift;
  my $dbh = shift;

  unless ($dbh) { croak 'Argument missing: database handle' };

  my $recipe_hash = $class->fetch_all_recipes($dbh);

  my $ingredient_hash = $class->fetch_all_ingredients($dbh, $recipe_hash);

  # #### add categories to recipe hash
  $recipe_hash = $class->fetch_all_categories($dbh, $recipe_hash);
  
  # return ($recipe_hash, $ingredient_hash);
  
}


sub export2html_collect_images
  ### collect image data needed for html export for ids given as keys of recipe hash
  ###   - images are extracted from db and stored at given location
  ###   - data about image location (file name) is added to recipe hash
  ### arguments (required)
  ###    - database handle
  ###    - recipe hash: key are ids for which to extract images
  ### arguments (optional - needed to compute image file name)
  ###    - html dir: where the html files, are stored - default currend dir
  ###    - pic dir: where image files are stored - default $html_dir/pics
  ### returns 
  ###    - the recipe hash with the additional image information
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_hash = shift;
  my $html_dir = shift;
  my $pic_dir = shift;

  unless ($dbh) { croak 'Argument missing: database handle' };
  unless ($recipe_hash) { croak 'Argument missing: list of ids (reference to array)' };
  unless ($html_dir) { $html_dir = '.' };
  unless ($pic_dir) { $pic_dir = "$html_dir/pics"; };

  my $ids = [ keys %{ $recipe_hash } ];

  my $id2image_file = $class->fetch_some_images($dbh, $ids, $pic_dir);
  # my $img_nbr = scalar(keys %{ $id2image_file });

  ### add file names of saved images to $recipe_hash
  foreach my $id (keys %{ $id2image_file }) {
    $recipe_hash->{$id}->{'image_file'} = $id2image_file->{$id};
  }

  return $recipe_hash;
  
}

sub export2html_collect_all_images
  ### collect image data needed for html export for all recipes in db
  ###   - images are extracted from db and stored at given location
  ###   - data about image location (file name) is added to recipe hash
  ### arguments (required)
  ###    - database handle
  ###    - recipe hash
  ### arguments (optional - needed to compute image file name)
  ###    - html dir: where the html files, are stored - default currend dir
  ###    - pic dir: where image files are stored - default $html_dir/pics
  ### returns 
  ###    - the recipe hash with the additional image information
{
  my $class = shift;
  my $dbh = shift;
  my $recipe_hash = shift;
  my $html_dir = shift;
  my $pic_dir = shift;

  unless ($dbh) { croak 'Argument missing: database handle' };
  unless ($recipe_hash) { croak 'Argument missing: recipe hash, containing data for recipes' };
  unless ($html_dir) { $html_dir = '.' };
  unless ($pic_dir) { $pic_dir = "$html_dir/pics"; };

  print STDERR "Retrieving and saving images...\n";
  my $id2image_file = $class->fetch_all_images($dbh, $pic_dir);
  # my $img_nbr = scalar(keys %{ $id2image_file });

  ### add file names of saved images to $recipe_hash
  foreach my $id (keys %{ $id2image_file }) {
    if (exists $recipe_hash->{$id}) {
      $recipe_hash->{$id}->{'image_file'} = $id2image_file->{$id};
    } else {
      print STDERR "Id $id: no entry in recipe hash\n";
    }
  }

  return $recipe_hash;
  
}

sub export2html_id
  ### build and save html file for given id, based on recipe and ingredient data
  ### collected previously from db
  ### arguments (required)
  ###   - recipe id
  ###   - recipe hash
  ###   - ingredient hash
  ### arguments (optional)
  ###   - max recipe id: if present is output in recipe description
  ###   - html dir: where to write html files - default current directory
  ###   - rel picture dir: picture directory in html file, default 'pics'
  ###     has to be relative to where the html file is
{
  my $class = shift;
  my $id = shift;
  my $recipe_hash = shift;
  my $ingredient_hash = shift;
  my $max_rid = shift;
  my $html_dir = shift;
  my $rel_picdir = shift;

  unless ($recipe_hash) { croak 'Argument missing: recipe hash' };
  unless ($ingredient_hash) { croak 'Argument missing: ingredient hash' };
  unless ($id) { croak 'Argument missing: recipe id' };
  unless ($html_dir) { $html_dir = '.' };
  unless ($rel_picdir) { $rel_picdir = 'pics'; };

  my $title = $recipe_hash->{$id}->{'title'};
  print STDERR "id: $id, title: $title\n";

  #### Where to save the html file to
  my $file_name = "$html_dir/$title$id.htm";


  ##################################
  ### Setup header of html document
  #
  # for header we need:
  # - title from recipe hash
  # - link to stylesheet: style.css

  my ($doc, $html) = $class->setup_html_header($title);


  ###########################################################
  ### the html body

  my $body = $doc->createElement('body');

  $html->appendChild($body);

  #############
  ### recipe header/description

  my $r_div = $class->make_html_recipe_description($doc, $recipe_hash, $id, $max_rid);

  ############# ingredients ###################

  $r_div = $class->make_html_recipe_ingredients($doc, $r_div, $ingredient_hash, $id);

  ######################################
  ### instructions

  $r_div = $class->make_html_recipe_instructions($doc, $r_div, $recipe_hash, $id);


  #################################################################
  ### modifications (i.e. notes)

  $r_div = $class->make_html_recipe_modifications($doc, $r_div, $recipe_hash, $id);

  $body->appendChild($r_div);

  $html->appendChild($body);

  $doc->setDocumentElement($html);


  $doc->toFile($file_name, 1);

};


sub make_id2file_name
  ### build and save information for recipes needed to build index.html file
  ### based on data extracted from db (recipe table)
  ### arguments (required)
  ###   - recipe hash
  ### returns: hash with ids as keys and title, category, rating and
  ### name of generated html file as value
{
  my $class = shift;
  my $recipe_hash = shift;
  unless ($recipe_hash) { croak 'Argument missing: recipe hash' };

  my $id2file_name = {};
  foreach my $id (keys %{ $recipe_hash }) {
    next unless ($id);
    my $title = 'No title';
    if ($recipe_hash->{$id}->{'title'}) {
      $title = $recipe_hash->{$id}->{'title'};
    } else {
      print STDERR "Recipe $id has no title\n";
    }
    $id2file_name->{$id}->{'title'} = $title;


    $id2file_name->{$id}->{'rating'} = $recipe_hash->{$id}->{'rating'};

    if (exists $recipe_hash->{$id}->{'category'}) {
      $id2file_name->{$id}->{'category'} = $recipe_hash->{$id}->{'category'};
    } else {
      print STDERR "Recipe $id $title has no category\n";
    };

    #### only keep ascii and blancs in title string
    my $title_sanitized = $title;
    $title_sanitized =~ s{[^A-Za-z0-9 ]}{}g;

    #### file name for links (in index file):
    my $file_name = "$title_sanitized$id.htm";

    $id2file_name->{$id}->{'html_file_name'} = $file_name;
    
  }

  return $id2file_name;

}

sub export2html_all
  ### build and save html file for all recipes, based on recipe and ingredient data
  ### collected previously from db
  ### arguments (required)
  ###   - recipe hash
  ###   - ingredient hash
  ### arguments (optional)
  ###   - max recipe id: if present is output in recipe description
  ###   - html dir: where to write html files - default current directory
  ###   - rel picture dir: picture directory in html file, default 'pics'
  ###     has to be relative to where the html file is
  ### returns: hash with ids as keys and name of generated html file as value 
{
  my $class = shift;
  my $recipe_hash = shift;
  my $ingredient_hash = shift;
  my $max_rid = shift;
  my $html_dir = shift;
  my $rel_picdir = shift;

  unless ($recipe_hash) { croak 'Argument missing: recipe hash' };
  unless ($ingredient_hash) { croak 'Argument missing: ingredient hash' };
  unless ($html_dir) { $html_dir = '.' };
  unless ($rel_picdir) { $rel_picdir = 'pics'; };

  my $id2file_name = $class->make_id2file_name($recipe_hash);

  print STDERR "Generating html files for all recipes...\n";

  foreach my $id (keys %{ $recipe_hash }) {


    my $title = $id2file_name->{$id}->{'title'};
    
    #### where to write the file
    my $file_name = $id2file_name->{$id}->{'html_file_name'};
    $file_name = "$html_dir/$file_name";
    
    
    ##################################
    ### Setup header of html document
    #
    # for header we need:
    # - title from recipe hash
    # - link to stylesheet: style.css

    my ($doc, $html) = $class->setup_html_header($title);


    ###########################################################
    ### the html body

    my $body = $doc->createElement('body');

    $html->appendChild($body);

    #############
    ### recipe header/description

    my $r_div = $class->make_html_recipe_description($doc, $recipe_hash, $id, $max_rid);

    ############# ingredients ###################

    $r_div = $class->make_html_recipe_ingredients($doc, $r_div, $ingredient_hash, $id);

    ######################################
    ### instructions

    $r_div = $class->make_html_recipe_instructions($doc, $r_div, $recipe_hash, $id);


    #################################################################
    ### modifications (i.e. notes)

    $r_div = $class->make_html_recipe_modifications($doc, $r_div, $recipe_hash, $id);

    $body->appendChild($r_div);

    $html->appendChild($body);

    $doc->setDocumentElement($html);


    $doc->toFile($file_name, 1);

  }

  
  return $id2file_name;
  
};

sub recipes_db2hashes
  ### save recipe_hash and ingredient hash to json files
  ### arguments (required)
  ###  - recipe_hash (reference)
  ###  - ingredient_hash (reference)
  ### arguments (optional)
  ###  - json file name for recipe_hash - defaults to recipes.json
  ###  - json file name for ingredients_hash - defaults to ingredients.json
{
  my $class = shift;
  my $recipe_hash = shift;
  my $ingredients_hash = shift;
  my $recipes_file_name = shift;
  my $ingredients_file_name = shift;

  unless ($recipe_hash) { croak "1. argument recipe hash missing\n"; };
  unless ($ingredients_hash) { croak "2. argument ingredients hash missing\n"; };

  unless ($recipes_file_name) { $recipes_file_name = 'recipes.json' };
  unless ($ingredients_file_name) { $ingredients_file_name = 'ingredients.json' };

  use JSON::XS qw(encode_json decode_json);
  use File::Slurp;

  my $json = encode_json($recipe_hash);
  write_file($recipes_file_name, { binmode => ':raw' }, $json);

  $json = encode_json($ingredients_hash);
  write_file($ingredients_file_name, { binmode => ':raw' }, $json);

};

__END__

