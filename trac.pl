# Copyright (c) 2008, Jannis Leidel
# All rights reserved.
#
# Changelog
# 
# 0.1 - initial release
# 0.1.1 - some fixes with dependencies for virtualmin-svn

# script_trac_desc()
sub script_trac_desc
{
return "Trac";
}

sub script_trac_uses
{
return ( "python" );
}

sub script_trac_longdesc
{
return "Enhanced wiki and issue tracking system for software development projects.";
}

# script_trac_versions()
sub script_trac_versions
{
return ( "0.11rc1" );
}

sub script_trac_python_modules
{
local ($d, $ver, $opts) = @_;
local ($dbtype, $dbname) = split(/_/, $opts->{'db'}, 2);
return ( "setuptools", "subversion", $dbtype eq "mysql" ? "MySQLdb" : "psycopg" );
}

# script_trac_depends(&domain, version)
# Check for ruby command, ruby gems, mod_proxy
sub script_trac_depends
{
local ($d, $ver) = @_;
&has_command("python") || return "The python command is not installed";
&has_command("svn") || return "The svn command is not installed";
&require_apache();
$d->{'virtualmin-svn'} || return "The SVN plugin is not enabled for this domain";
local $conf = &apache::get_config();
local $got_rewrite;
foreach my $l (&apache::find_directive("LoadModule", $conf)) {
	$got_rewrite++ if ($l =~ /mod_rewrite/);
	}
$apache::httpd_modules{'mod_fcgid'} ||
	return "Apache does not have the mod_fcgid module";
$apache::httpd_modules{'mod_rewrite'} || $got_rewrite ||
	return "Apache does not have the mod_rewrite module";
return undef;
}

# script_trac_params(&domain, version, &upgrade-info)
# Returns HTML for table rows for options for installing PHP-NUKE
sub script_trac_params
{
local ($d, $ver, $upgrade) = @_;
local $rv;
local $hdir = &public_html_dir($d, 1);
if ($upgrade) {
	# Options are fixed when upgrading
	local ($dbtype, $dbname) = split(/_/, $upgrade->{'opts'}->{'db'}, 2);
	$rv .= &ui_table_row("Database for Trac", $dbname);
	$rv .= &ui_table_row("SVN repository", $upgrade->{'opts'}->{'rep'});
	$rv .= &ui_table_row("Trac project name", $upgrade->{'opts'}->{'project'});
	local $dir = $upgrade->{'opts'}->{'dir'};
	$dir =~ s/^$d->{'home'}\///;
	$rv .= &ui_table_row("Install directory", $dir);
	$rv .= &ui_table_row("Trac admin user", $upgrade->{'opts'}->{'tracadmin'});
	}
else {
	&foreign_require("virtualmin-svn", "virtualmin-svn-lib.pl");
	# Show editable install options
	local @dbs = &domain_databases($d, [ "mysql", "postgres" ]);
	local @reps = &virtualmin_svn::list_reps($d);
	local @users = &virtualmin_svn::list_users($d);
	$rv .= &ui_table_row("Database for Trac",
			 &ui_database_select("db", undef, \@dbs, $d, "trac"));
	$rv .= &ui_table_row("SVN repository",
			 &ui_select("rep", undef,
			 [ map { [ $_->{'rep'}, $_->{'rep'} ] } @reps ]));
	$rv .= &ui_table_row("Trac project name",
			 &ui_textbox("project", "trac", 30));
	$rv .= &ui_table_row("Install sub-directory under <tt>$hdir</tt>",
				 &ui_opt_textbox("dir", undef, 30,
						 "At top level"));
	$rv .= &ui_table_row("Trac admin user",
			 &ui_select("tracadmin", undef,
			 [ map { [ $_->{'user'}, $_->{'user'} ] } @users ]));
	}
return $rv;
}

# script_trac_parse(&domain, version, &in, &upgrade-info)
# Returns either a hash ref of parsed options, or an error string
sub script_trac_parse
{
local ($d, $ver, $in, $upgrade) = @_;
if ($upgrade) {
	# Options are always the same
	return $upgrade->{'opts'};
	}
else {
	local $hdir = &public_html_dir($d, 0);
	$in->{'dir_def'} || $in->{'dir'} =~ /\S/ && $in->{'dir'} !~ /\.\./ ||
		return "Missing or invalid installation directory";
	local $dir = $in->{'dir_def'} ? $hdir : "$hdir/$in->{'dir'}";
	$in{'project'} =~ /^[a-z0-9]+$/ ||
		return "Project name can only contain letters and numbers";
	local ($newdb) = ($in->{'db'} =~ s/^\*//);
	return { 'db' => $in->{'db'},
		 'newdb' => $newdb,
		 'dir' => $dir,
		 'rep' => $in{'rep'},
		 'tracadmin' => $in{'tracadmin'},
		 'path' => $in->{'dir_def'} ? "/" : "/$in->{'dir'}",
		 'project' => $in{'project'} };
	}
}

# script_trac_check(&domain, version, &opts, &upgrade-info)
# Returns an error message if a required option is missing or invalid
sub script_trac_check
{
local ($d, $ver, $opts, $upgrade) = @_;
$opts->{'dir'} =~ /^\// || return "Missing or invalid install directory";
$opts->{'db'} || return "Missing database";
$opts->{'rep'} || return "Missing SVN repository. Please create one first.";
if (-r "$opts->{'dir'}/trac.fcgi") {
	return "Trac appears to be already installed in the selected directory";
	}
$opts->{'project'} || return "Missing Trac project name";
$opts->{'tracadmin'} || return "Missing Trac admin user";
$opts->{'project'} =~ /^[a-z0-9]+$/ ||
	return "Project name can only contain letters and numbers";
return undef;
}

# script_trac_files(&domain, version, &opts, &upgrade-info)
# Returns a list of files needed by Rails, each of which is a hash ref
# containing a name, filename and URL
sub script_trac_files
{
local ($d, $ver, $opts, $upgrade) = @_;
local @files = (
	 { 'name' => "source",
	   'file' => "Trac-$ver.tar.gz",
	   'url' => "http://ftp.edgewall.com/pub/trac/Trac-$ver.tar.gz" },
	 { 'name' => "genshi",
	   'file' => "Genshi-0.4.4.tar.gz",
	   'url' => "http://ftp.edgewall.com/pub/genshi/Genshi-0.4.4.tar.gz" },
	 { 'name' => "flup",
	   'file' => "flup-1.0.tar.gz",
	   'url' => "http://www.saddi.com/software/flup/dist/flup-1.0.tar.gz" },
	);
return @files;
}

sub script_trac_commands
{
local ($d, $ver, $opts) = @_;
return ("python");
}

# script_trac_install(&domain, version, &opts, &files, &upgrade-info)
# Actually installs PhpWiki, and returns either 1 and an informational
# message, or 0 and an error
sub script_trac_install
{
local ($d, $version, $opts, $files, $upgrade, $domuser, $dompass) = @_;
local ($out, $ex);

# Get database settings
if ($opts->{'newdb'} && !$upgrade) {
	local $err = &create_script_database($d, $opts->{'db'});
	return (0, "Database creation failed : $err") if ($err);
	}
local ($dbtype, $dbname) = split(/_/, $opts->{'db'}, 2);
local $dbuser = $dbtype eq "mysql" ? &mysql_user($d) : &postgres_user($d);
local $dbpass = $dbtype eq "mysql" ? &mysql_pass($d) : &postgres_pass($d, 1);
local $dbhost = &get_database_host($dbtype);
if ($dbtype) {
	local $dberr = &check_script_db_connection($dbtype, $dbname,
						   $dbuser, $dbpass);
	return (0, "Database connection failed : $dberr") if ($dberr);
	}
local $python = &has_command("python");

# Create target dir
if (!-d $opts->{'dir'}) {
	$out = &run_as_domain_user($d, "mkdir -p ".quotemeta($opts->{'dir'}));
	-d $opts->{'dir'} ||
		return (0, "Failed to create directory : <tt>$out</tt>.");
	}

# Create python base dir
$ENV{'PYTHONPATH'} = "$opts->{'dir'}/lib/python";
&run_as_domain_user($d, "mkdir -p ".quotemeta($ENV{'PYTHONPATH'}));

# Extract the source, then install to the target dir
local $temp = &transname();
local $err = &extract_script_archive($files->{'source'}, $temp, $d);
$err && return (0, "Failed to extract Trac source : $err");
local $icmd = "cd ".quotemeta("$temp/Trac-$ver")." && ".
	  "python setup.py install --home ".quotemeta($opts->{'dir'})." 2>&1";
local $out = &run_as_domain_user($d, $icmd);
if ($?) {
	return (0, "Trac source install failed : ".
		   "<pre>".&html_escape($out)."</pre>");
	}

# Extract and copy the flup source
local $err = &extract_script_archive($files->{'flup'}, $temp, $d);
$err && return (0, "Failed to extract flup source : $err");
local $out = &run_as_domain_user($d, 
	"cp -r ".quotemeta("$temp/flup-1.0/flup").
	" ".quotemeta("$opts->{'dir'}/lib/python"));
if ($?) {
	return (0, "flup source copy failed : ".
		   "<pre>".&html_escape($out)."</pre>");
	}

# Extract and install genshi
local $err = &extract_script_archive($files->{'genshi'}, $temp, $d);
$err && return (0, "Failed to extract Genshi source : $err");
local $icmd = "cd ".quotemeta("$temp/Genshi-0.4.4")." && ".
	  "python setup.py install --home ".quotemeta($opts->{'dir'})." 2>&1";
local $out = &run_as_domain_user($d, $icmd);
if ($?) {
	return (0, "Genshi source copy failed : ".
		   "<pre>".&html_escape($out)."</pre>");
	}

if (!$upgrade) {
	# Fix database name
	if ($dbtype eq 'postgres') {
	  $dbhost = "";
	  }
	# Create the initial project
	local $projectdir = $opts->{'dir'}."/".$opts->{'project'};
	local $icmd = "cd ".quotemeta($opts->{'dir'})." && ".
		  "./bin/trac-admin ".$projectdir." initenv ".$opts->{'project'}." ".
		  $dbtype."://".$dbuser.":".$dbpass."@".$dbhost."/".$dbname.
		  " svn ".$d->{'home'}."/svn/".$opts->{'rep'}." 2>&1 && ".
		  "./bin/trac-admin ".$projectdir." permission add ".
		  $opts->{'tracadmin'}." TRAC_ADMIN 2>&1";
	local $out = &run_as_domain_user($d, $icmd);
	if ($?) {
		return (0, "Project initialization install failed : ".
			   "<pre>".&html_escape($out)."</pre>");
		}
	# Fix trac.ini
	local $url = &script_path_url($d, $opts);
	local $sfile = "$projectdir/conf/trac.ini";
	-r $sfile || return (0, "Trac settings file $sfile was not found");
	local $lref = &read_file_lines($sfile);
	local $url = &script_path_url($d, $opts);
	local $adminpath = $opts->{'path'} eq "/" ?
		  "/admin" : "$opts->{'path'}/admin";
	my $i = 0;
	foreach my $l (@$lref) {
	  if ($l =~ /authz_file\s*=/) {
		  $l = "authz_file = $d->{'home'}/etc/svn-access.conf";
		  }
	  if ($l =~ /^url\s*=/) {
		  $l = "url = $opts->{'path'}";
		  }
	  if ($l =~ /^base_url\s*=/) {
		  $l = "base_url = $url";
		  }
	  if ($l =~ /^link\s*=/) {
		  $l = "link = $opts->{'path'}";
		  }
	  if ($l =~ /authz_module_name\s*=/) {
		  $l = "authz_module_name = $opts->{'rep'}";
		  }
	  if ($l =~ /src\s*=/) {
		  $l = "src = common/trac_banner.png";
		  }
	  if ($l =~ /alt\s*=/) {
		  $l = "alt = Trac logo";
		  }
	  if ($l =~ /^admin\s*=/) {
		  $l = "admin = $adminpath";
		  }
	  $i++;
	  }
	&flush_file_lines($sfile);
	}

# Create python fcgi wrapper script
local $fcgi = "$opts->{'dir'}/trac.fcgi";
local $wrapper = "$opts->{'dir'}/trac.fcgi.py";
&open_tempfile(FCGI, ">$fcgi");
&print_tempfile(FCGI, "#!/bin/sh\n");
&print_tempfile(FCGI, "export PYTHONPATH=$opts->{'dir'}/lib/python\n");
&print_tempfile(FCGI, "exec $python $wrapper\n");
&close_tempfile(FCGI);
&set_ownership_permissions($d->{'uid'}, $d->{'ugid'}, 0755, $fcgi);

# Create python fcgi wrapper
if (!-r $wrapper) {
	&open_tempfile(WRAPPER, ">$wrapper");
	&print_tempfile(WRAPPER, "#!$python\n");
	&print_tempfile(WRAPPER, "import sys, os\n");
	&print_tempfile(WRAPPER, "os.environ['TRAC_ENV'] = \"$opts->{'dir'}/$opts->{'project'}\"\n");
	&print_tempfile(WRAPPER, "os.environ['PYTHON_EGG_CACHE'] = \"$d->{'home'}/tmp\"\n");
	&print_tempfile(WRAPPER, "os.chdir(\"$opts->{'dir'}\")\n");
	&print_tempfile(WRAPPER, "from trac.web.main import dispatch_request\n");
	&print_tempfile(WRAPPER, "from flup.server.fcgi import WSGIServer\n");
	&print_tempfile(WRAPPER, "WSGIServer(dispatch_request).run()\n");
	&close_tempfile(WRAPPER);
	&set_ownership_permissions($d->{'uid'}, $d->{'ugid'}, 0755, $wrapper);
	}

# Add <Location> block to Apache config
&foreign_require("virtualmin-svn", "virtualmin-svn-lib.pl");
%sconfig = &foreign_config("virtualmin-svn");
$sconfig{'auth'} ||= "Basic";
local $conf = &apache::get_config();
local @ports = ( $d->{'web_port'},
		 $d->{'ssl'} ? ( $d->{'web_sslport'} ) : ( ) );
foreach my $port (@ports) {
	local ($virt, $vconf) = &get_apache_virtual($d->{'dom'}, $port);
	next if (!$virt);
	local $passwd_file = &virtualmin_svn::passwd_file($d);
	local $ap = $opts->{'path'} eq "/" ? "/login" : "$opts->{'path'}/login";
	local $at = $sconfig{'auth'};
	local $auf = $at eq "Digest" && $apache::httpd_modules{'core'} < 2.2 ?
			"AuthDigestFile" : "AuthUserFile";
	local $adp = $at eq "Digest" && $apache::httpd_modules{'core'} >= 2.2 ?
			"AuthDigestProvider" : "";
	local $adv = $at eq "Digest" && $apache::httpd_modules{'core'} >= 2.2 ?
			"file" : "";
	local @sa = &apache::find_directive("ScriptAlias", $vconf);
	local ($tc) = grep { $_ =~ /^\$opts->{'path'}/ } @sa;
	if (!$tc) {
		push(@sa, "$opts->{'path'} $fcgi/");
		&apache::save_directive("ScriptAlias", \@sa,
					$vconf, $conf);
		}
	local @locs = &apache::find_directive_struct("Location", $vconf);
	local ($loc) = grep { $_->{'words'}->[0] eq $ap } @locs;
	next if ($loc);
	local $loc = { 'name' => 'Location',
			   'value' => "$ap",
			   'type' => 1,
			   'members' => [
			{ 'name' => 'AuthType',
			  'value' => "$at" },
			{ 'name' => 'AuthName',
			  'value' => "$d->{'dom'}" },
			{ 'name' => "$auf",
			  'value' => "$passwd_file" },
			{ 'name' => "$adp",
			  'value' => "$adv" },
			{ 'name' => 'Require',
			  'value' => 'valid-user' },
			]
		};
	&apache::save_directive_struct(undef, $loc, $vconf, $conf);
	&flush_file_lines($virt->{'file'});
	}
&register_post_action(\&restart_apache);

local $url = &script_path_url($d, $opts);
local $rp = $opts->{'dir'};
$rp =~ s/^$d->{'home'}\///;
return (1, "Initial Trac installation complete. Go to <a target=_new href='$url'>$url</a> and login as <tt>$opts->{'tracadmin'}</tt> to manage.", $url);

}

# script_trac_uninstall(&domain, version, &opts)
# Un-installs a Trac installation, by deleting the directory and database.
# Returns 1 on success and a message, or 0 on failure and an error
sub script_trac_uninstall
{
local ($d, $version, $opts) = @_;

# Remove the contents of the target directory
local $derr = &delete_script_install_directory($d, $opts);
return (0, $derr) if ($derr);

# Remove base Django tables from the database
local ($dbtype, $dbname) = split(/_/, $opts->{'db'}, 2);
if ($dbtype eq 'mysql') {
	&require_mysql();
	foreach $t (&mysql::list_tables($dbname)) {
		&mysql::execute_sql_logged($dbname,
			"drop table ".&mysql::quotestr($t));
		}
	}
else {
	&require_postgres();
	foreach $t (&postgresql::list_tables($dbname)) {
		&postgresql::execute_sql_logged($dbname,
			"drop table ".&postgresql::quote_table($t)." cascade");
		}
	}

# Remove <Location> block
&require_apache();
local $conf = &apache::get_config();
local @ports = ( $d->{'web_port'},
		 $d->{'ssl'} ? ( $d->{'web_sslport'} ) : ( ) );
foreach my $port (@ports) {
	local ($virt, $vconf) = &get_apache_virtual($d->{'dom'}, $port);
	next if (!$virt);
	local $ap = $opts->{'path'} eq "/" ? "/login" : "$opts->{'path'}/login";
	local @locs = &apache::find_directive_struct("Location", $vconf);
	local ($loc) = grep { $_->{'words'}->[0] eq $ap } @locs;
	next if (!$loc);
	&apache::save_directive_struct($loc, undef, $vconf, $conf);
	&flush_file_lines($virt->{'file'});
	}
&register_post_action(\&restart_apache);

# Take out the DB
if ($opts->{'newdb'}) {
	&delete_script_database($d, $opts->{'db'});
	}

return (1, "Trac directory and tables deleted.");
}

# script_trac_latest(version)
# Returns a URL and regular expression or callback func to get the version
sub script_trac_latest
{
local ($ver) = @_;
return ( "http://trac.edgewall.org/wiki/TracDownload",
	 "Trac-([a-z0-9\\.]+).tar.gz" );
}

sub script_trac_site
{
return 'http://trac.edgewall.org/';
}

1;

