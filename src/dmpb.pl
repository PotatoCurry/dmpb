#!/usr/bin/perl
use feature ':5.30';
use strict;
use warnings;
use autodie;
use FindBin '$RealBin';
use lib $RealBin;

use Config::Tiny;
use File::Path;
use File::Path qw(make_path);
use XML::RSS;
use Template;
use Text::Markdown 'markdown';
use Time::Piece;

use Post;

my $config = Config::Tiny->read("config.ini");
my $blog_title = $$config{blog}{title};
my $blog_description = $$config{blog}{description};
my $author = $$config{blog}{author};
my $blog_location = $$config{blog}{location};

if ($#ARGV == -1) {
	say "[Help Message]";
} elsif ($ARGV[0] eq "new") {
	die "No post title given" if ($#ARGV == 0);
	my $title = $ARGV[1];
	my $post_file = "blog/$title";
	$post_file .= ".md" unless $post_file =~ /\.md$/;
	die "$post_file already exists" if -e $post_file;
	open(my $post_out, ">", $post_file);
	say $post_out $title;
	say $post_out localtime->date;
	say $post_out "new,empty,post";
	say $post_out "\nPost Content";
	close $post_out;
	say "Created new post at $post_file";
} elsif ($ARGV[0] eq "build") {
	build_output();
	say "Finished building output";
} else {
	die "Unable to parse arguments";
}

sub build_output {
	# Clear output directory
	rmtree "out";

	# Process blog entries
	my $templates = Template->new({INCLUDE_PATH => "templates"});
	my @blog_files = <blog/*.md>;
	my @posts = ();
	foreach my $blog_file (@blog_files) {
		my $post = read_post($blog_file);
		create_blog_entry($post, $templates);
		push(@posts, $post);
	}
	
	create_blog_index(@posts, $templates);
	create_rss_feed(@posts);
}

sub read_post {
	my $md_file = shift;
	open(my $md_in,  "<",  $md_file);
	my @raw = <$md_in>;
	close $md_in;
	
	my $title = $raw[0];
	my $raw_date = $raw[1];
	chomp $raw_date;
	my $date = Time::Piece->strptime($raw_date, "%F");
	my @tags = split(",", $raw[2]);
	my @md_content = join("", @raw[4..$#raw]);
	my $html_content = markdown(@md_content);
	return Post->new({
		file => $md_file,
		title => $title,
		date => $date,
		tags => @tags,
		content => $html_content
	});
}

sub create_blog_entry {
	my $post = shift;
	my $templates = shift;
	my $html_file = $post->{file} =~ s/\.md$/\/index.html/r;
	my $date_folders = $post->{date}->ymd("/");
	my $html_location = "out/$blog_location/$date_folders";
	make_path $html_location;
	$html_file =~ s/^blog/$html_location/;
	my $blog_data = {author => $author, post => $post};
	$templates->process("post.tt2", $blog_data, $html_file);
	$html_file =~ s/out\/$blog_location\///;
	$html_file =~ s/\/index\.html$//;
	$post->{file} = $html_file;
}

sub create_blog_index {
	my @posts = shift;
	my $templates = shift;
	my $index_file = "out/$blog_location\/index.html";
	my $blog_data = {
		title => $blog_title,
		description => $blog_description,
		author => $author,
		posts => @posts
	};
	$templates->process("blog.tt2", $blog_data, $index_file);
}

sub create_rss_feed {
	my @posts = shift;
	my $rss_feed = XML::RSS->new(version => "2.0");
	$rss_feed->channel(
		title => $blog_title,
		description => $blog_description
	);
	
	foreach my $post (@posts) {
		$rss_feed->add_item(
			title => $post->{title},
			description => $post->{content}
		);
	}
	
	my $rss_file = "out/$blog_location/rss.xml";
	open(my $rss_out, ">", $rss_file);
	print $rss_out $rss_feed->as_string;
	close $rss_out;
}
