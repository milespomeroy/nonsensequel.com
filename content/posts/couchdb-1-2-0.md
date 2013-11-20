---
title: "New Features in CouchDB 1.2.0"
date:  "2012-05-19"
---

CouchDB 1.2.0 was released [April 6](https://blogs.apache.org/couchdb/entry/apache_couchdb_1_2_0). So far it seems that the [rumors of CouchDB's death](http://damienkatz.net/2012/01/the_future_of_couchdb.html) were greatly exaggerated. The Apache community developing CouchDB is still pushing out some great stuff. Two of the most anticipated features of this release are automatic compaction and enhanced security.

Automatic Compaction
--------------------

Due to the revisionist nature of CouchDB, an update heavy database can get very large very quickly. To prevent your database from getting exorbitantly large, you have to invoke a compaction on your database and associated views. Compaction deletes old revisions and other unnecessary data that accumulates with updates. The common approach is to use a cron job that runs periodically calling the compaction command. This seems cumbersome compared to the automatic compaction that occurs with other NoSQL solutions like Riak.

In 1.2 we finally get automatic compaction baked in, but it is disabled by default. For casual users and developers working with CouchDB on their local box, compaction is less of an issue and the potential loss of document revisions may cause frustration. The developers of CouchDB might also be timid about choosing sensible defaults for compaction that do not aggravate users. Either way, they decided to leave it off by default and require an administrator to determine what is appropriate for their databases.

To enable automatic compaction, entries need to be made in the `local.ini` file (or on the configuration page in Futon) to describe when a compaction should be triggered. Settings can be made for individual databases or globally through a `_default` option. The new `default.ini` has a comprehensive explanation of how to set it up. The explanation is so good, that it's copied nearly word for word on the [CouchDB wiki](http://wiki.apache.org/couchdb/Compaction#Automatic_Compaction).

With the new release, CouchDB now includes a compaction daemon that will check which databases and/or views need to be compacted based on the compaction rules configured. The default `check_interval` for the daemon is every five minutes. To prevent compactions from running during peak usage hours, an approved window can be defined; during which time compactions will be allowed to take place.

The example rule given in the `default.ini` file is:

    _default = [{db_fragmentation, "70%"}, {view_fragmentation, "60%"}, {from, "23:00"}, {to, "04:00"}]

`_default`: states that this is a global rule that should take effect on every database that does not have a database specific rule. To create a database specific rule, `_default` would be replaced with the database name.

`{db_fragmentation, "70%"}`: relies on a new `data_size` property that is reported when `GET`ing the database group information URIs, i.e. `GET /db_name`.[^1] `data_size` is how much of the `disk_size` (a.k.a. `file_size`) actually contains your data. The difference between the `disk_size` and the `data_size` is the amount of space that could be reclaimed with a compaction. So this parameter is saying that a compaction should be triggered when 70% or more of the reported `disk_size` can be reclaimed.

[^1]: For me this property reported null on all my databases that existed prior to the upgrade until I manually ran a compaction which, according to the "[Breaking Changes](http://wiki.apache.org/couchdb/Breaking_changes#Changes_Between_1.1.0_and_1.2.0)" document on the wiki, causes an upgrade of the disk files; which I assume enables this new property. It makes me wonder if automatic compaction will even work on existing databases until a manual compaction has been invoked, causing the needed upgrade of the data files.

`{view_fragmentation, "60%"}`: is similar to the `db_fragmentation` parameter but specific to the views of the database in question.

`{from, "23:00"}, {to, "04:00"}`: is the allowed time period or window for when compactions can be triggered based on the other parameters in the rule. In this example it is 11 PM to 4 AM server time. If the parameter `{strict_window, true}` were added to this rule, then any compactions that were in process at the end of the window, 4 AM, would be cancelled.

Whenever a compaction is triggered by the daemon, it first checks that enough free space exists on disk to complete the compaction. Compaction occurs on a copy of the data file and the compacted file is then swapped with the existing file, so the daemon checks that at least twice the size of the data file exists as free space on the disk. If not, the compaction does not occur and a warning message is logged.

Enhanced Security
-----------------

Security seems to be something at the bottom of every NoSQL's to do list. I've heard some vendors say that their customers aren't asking for it. That may be true for the mostly internet companies that were actively using NoSQL early on, but now old fashion enterprises are showing interest in NoSQL and to them security is essential.

CouchDB has been ahead of the game on this front. Maybe because it's an older contender or because of the necessity to have strong security when you have the database available from the open web as is the case when hosting CouchApps. Either way, the `_users` database, access controls, and authentication in general seem to have been around a long time---although the documentation on these features is pretty flaky.

One of the things I always thought was strange with CouchDB security was that, by default, any user can see any other user's document in the `_users` database---giving them access to the password and salt. Now the password isn't stored in plaintext, it's stored as a SHA-1 hash of that password. But with that hash and the salt (which is stored in plaintext), a hacker could figure out your password fairly quickly.

To increase the security of the `_users` database pre-1.2, I've resorted to setting the security to `"nobody"`. That way only a server admin can view and administer users. Unfortunately, this breaks the user features of Futon, prevents non-admin users from changing their password, and disables the ability for new users to sign up on their own. Making this change also caused me to jump through some hoops to create new users since their's not a link in Futon, once logged in as a server admin, to add a new user. I either had to create the user manually by `POST`ing a preconfigured user document, complete with the `password_sha` and `salt` already generated,[^salt] or I had to use a little javascript bookmarklet I created to call the javascript function normally bound to the signup link. Which had the unfortunate side effect of logging me out of my session as a server admin and into the non-privileged account just created.

[^salt]: The `password_sha` and `salt` field are now automatically generated for you when you supply a `password` attribute in a new user document. This should allow the CouchDB developers the ability to further increase password hashing security by introducing more sophisticated hashing algorithms---see [Jira Issue 1060](https://issues.apache.org/jira/browse/COUCHDB-1060). For more information on password hashing check out: [Use bcrypt](http://codahale.com/how-to-safely-store-a-password/) and [Don't use bcrypt](http://www.unlimitednovelty.com/2012/03/dont-use-bcrypt.html) (via [Daniel Jalkut](http://www.red-sweater.com/blog/2400/secure-password-storage)).

In 1.2 they made this all much better. By default normal users can now only read and update their *own* user docs.[^ud] New users are still able to create a new user document for themselves, but all other functions of the `_users` database must be done by either a server admin or a `_users` database admin; including the adding of roles to the user, done by updating the `"roles"` attribute on an individual's user document.

[^ud]: The Futon interface on this could be improved. As a normal user you can't view all the docs in the `_users` database. So if you click on the `_users` database from the "Overview" screen you will be given a `forbidden` error message. If you fiddle with the URL you can get it to show you your own, but if you get it wrong there is no message and the spinner just spins forever. Behind the scenes the database is returning a `not_found` error message, but Futon is not handling it correctly.

The `_replicator` database has also received similar security improvements. Currently if you have a replication that needs credentials for connecting to the target or source database, those credentials need to be stored in the document in plaintext. Anyone who is a reader of the `_replicator` database can then view the password. In 1.2, the owner of each replicator document is kept track up of via a new `owner` attribute. When a non-admin, non-owner reads another user's replication document the username and password are omitted and they are unable to update the document.

If you use the OAuth features in CouchDB, you can now store OAuth tokens and secrets in the individual user documents. Which, like passwords, can only be seen by the user and admins. Similarly OAuth tokens and secrets in replication documents are stripped when viewed by a non-admin, non-owner user. Be aware that in order to store OAuth credentials in user documents you must set `use_users_db` to `true` in the `couch_httpd_oauth` section of the configuration.

Other Noteworthy Improvements
-----------------------------

### Futon UI

{{%figure caption="CouchDB 1.2 Sidebar" src="/images/couchdb-1.2-sidebar.png" %}}

A couple of minor changes to the sidebar: there is a new "Verify Installation" screen, which seems to be a subset of tests pulled out of the "Test Suite." The "Test Suite" link is now segregated with a subheading of "For Developers." Which suggests to the user that they shouldn't run the tests unless they know what they're doing. I'm sure many new users---myself included---ran the full "Test Suite" just trying to see if they installed CouchDB properly and ended up with weird errors that they really didn't need to worry about. The new "Verify Installation" task is a lot simpler and satisfies this need.

{{%figure caption="CouchDB 1.2 Status" src="/images/couchdb-1.2-status.png" %}}

New to the "Status" screen are the "Started on" and "Last updated on" columns.

In the Futon section of the [release notes](http://www.apache.org/dist/couchdb/notes/1.2.0/apache-couchdb-1.2.0.html) it claims that, "Running replications can now be cancelled with a single click." I couldn't find that feature in the `_replicator` database screens or on the "Status" screen. I think they got confused with the new ability to [cancel a replication](http://wiki.apache.org/couchdb/Replication#Cancel_replication) using just the `replication_id` rather than having to specify the `target` and `source`. I can see how this feature could make a replication cancel button easier to implement in the UI. Hopefully that comes soon.

### CoffeeScript Support

Although not mentioned in the [release notes](http://www.apache.org/dist/couchdb/notes/1.2.0/apache-couchdb-1.2.0.html), you can now write your map/reduce code in [CoffeeScript](http://coffeescript.org/)---if that appeals to you. Just specify `"language": "coffeescript"` in your design docs.

### File Compression

Databases and views in 1.2 take up less space on disk. Google's [snappy compressor](http://code.google.com/p/snappy/) is used to shrink the size of the data stored on disk.[^confuse] This feature is enabled by default, but existing databases and views will need to be upgraded to the new on-disk format. This occurs on the next compaction after the upgrade. If desired, the compression algorithm can be changed. Check out `default.ini` for all the options.

[^confuse]: Don't confuse this with compaction.

### Replicator Configuration Enhancements

Apparently the replicator was rewritten from scratch. It boasts a number of performance improvements and tons of new configuration options to control it to your hearts desire.

tl;dr
-----

Version 1.2.0 provides some very useful new features. It's well worth the upgrade.
