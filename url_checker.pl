#!/usr/bin/env perl

use warnings;
use strict;
#use Digest::SHA1 qw/sha1_hex/;
use LWP::UserAgent;
use Pithub;

my %config = do '/secret/github.config';

if(-d "free-programming-books"){
	chdir("free-programming-books");
	#grab the latest changes
	system("git pull origin master");
	chdir("../.");
}else{
	system("git clone https://github.com/vhf/free-programming-books.git");
}

chdir("free-programming-books");
my @books = <free-programming-books*.md>;

#gotta add 2 more books that dont conform to the usual naming convention
push(@books,'free-programming-interactive-tutorials-en.md');
push(@books,'javascript-frameworks-resources.md');

my %db;

foreach my $book (@books){
	local $/ = undef;
	open FILE, "$book" or die "Couldn't open file: $!";
	my $content = <FILE>;
	close FILE;
	$db{$book}{"content"}=$content;
}

my $ua = LWP::UserAgent->new;
$ua->agent("Mozilla/5.0");
$ua->timeout(120);
#$ua->show_progress(1);

my $c = Pithub::Repos::Commits->new( token => $config{'token'});

foreach my $book (keys %db){
	my @content = split("\n", $db{$book}{'content'});
	foreach my $line (@content){

		# THIS IS THE PART THAT NEEDS TO BE FIXED TO ACCOUNT FOR PARENS in the url

		if($line =~ /\[.*\].*\(.*(http:\/\/.*?)\)/){
			#print "$1\n";
			my $url=$1;
			my $test = &test_url($url);


			if($test ne 'good'){
				my $lang="en";
				if($book =~ /free-programming-books-(.*)\.md/){
					$lang=$1;
				}elsif($book eq 'javascript-frameworks-resources.md'){
					$lang='jfr';
				}elsif($book eq 'free-programming-interactive-tutorials-en.md'){
					$lang='fpite';
				}

				#figure out which commit added this bad url
				my $commit = `git log -S$url --reverse --format=%H | head -1`;
				chomp($commit);

				#figure out the commit's author's login so we take a closer
				#look at this single commit and look for the login info
				my $cc = $c->get(
					user => 'vhf',
					repo => 'free-programming-books',
					sha  => $commit,
				);
				my $committer = $cc->content->{author}->{login};

				print "$test\nIt was added by \@$committer in $commit. label: $lang\t title: $url\n";

			}
		}
	}
}

sub test_url{
	my $retval;
	my $url = shift @_;
	my $req = HTTP::Request->new(HEAD => $url);
	my $res = $ua->request($req);

	### CHANGE HERE TO THE MAKE HE CHECK LESS STRINGENT 

	if($res->is_success){
		$retval = "good";
	}else{
		#try one more time with GET
		$req = HTTP::Request->new(GET => $url);
		$ua->timeout(360); #wait 6 mins in case it's really slow
		$res = $ua->request($req);
		if($res->is_success){
			$retval = "good";
		}else{
			$retval = $res->status_line."\n$url";
		}
	}
	return $retval;
}
