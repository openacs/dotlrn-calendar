
# Procs for DOTLRN calendar Applet
# Copyright 2001 OpenForce, inc.
# Distributed under the GNU GPL v2
#
# October 26th, 2001
#

ad_library {
    
    Procs to set up the dotLRN calendar applet
    
    @author ben@openforce.net,arjun@openforce.net
    @creation-date 2001-10-26
    
}

namespace eval dotlrn_calendar {
    
    ad_proc -public package_key {
    } {
	get the package_key this applet deals with
    } {
	return "calendar"
    }

    ad_proc portal_element_key {
    } {
	return the portal element key
    } {
	return "calendar-portlet"
    }

    ad_proc -public get_pretty_name {
    } {
	returns the pretty name
    } {
	return "dotLRN Calendar"
    }

    ad_proc -public add_applet {
    } {
	Called for one time init - must be repeatable!
    } {

	# XXX testing - abstract out
	# only one instance of calendar for dotlrn, unlike other applets. 
	#
	# this is ugly, but the site_node proc throws errors on misses!

	set result ""
	if {[catch {nsv_get site_nodes [apm_package_url_from_key "dotlrn"]} \
		result] == 0} {
	    ns_log notice "aks90: site_nodes array hit!"
	} else {
	    ns_log notice "aks90: site_node array miss: $result\n
	    [apm_package_url_from_key "dotlrn"] \n
	    nsv info: [nsv_array get site_nodes]"
	}
    
	if {$result != 0} {
	    ns_log warning "aks92: dotlrn_calendar::add_applet creating...!"
#
#	     db_transaction {
#		 # calling directly since below proc has issues
#		 # set node_id [site_node_create $dotlrn_node_id  "calendar"]
#		 set new_node_id [db_nextval acs_object_id_seq]
#		 set dotlrn_node_id [dotlrn::get_node_id]
#		 set name "dotlrn-calendar"
#
#		 set node_id [db_exec_plsql create_cal_node {
#		     begin
#
#		     :1 := site_node.new (
#		     node_id => :new_node_id,
#		     parent_id => :dotlrn_node_id,
#		     name => :name,
#		     directory_p => 'f');
#		     end;
#		 }]
#		 
#		 # instanciate calendar there
#		 site_node_create_package_instance $node_id \
#			 [get_pretty_name] \
#			 [dotlrn::get_package_id] \
#			 [package_key]
#
#	     }
	} else {
	    ns_log warning "aks92: dotlrn_calendar::add_applet already here!"
	}

	return 1
    }

    ad_proc -public add_applet_to_community {
	community_id
    } {
	Add the calendar applet to a specific dotlrn community
    } {

	ns_log notice "aks91: dotlrn_calendar add_applet_to_community called"

	# aks XXX fixme

	# create the calendar package instance (all in one, I've mounted it)
	# set package_key [package_key]

	# XXX aks - don't mount here
	# set package_id [dotlrn::instantiate_and_mount $community_id $package_key]

	# first get the community name from dotlrn
	set community_name "The [dotlrn_community::get_community_name $community_id] Public Calendar"

	# create a community calendar, the "f" is for a public calendar
	set group_calendar_id \
		[calendar_create [ad_conn "user_id"] "f" $community_name]

	# add this element to the portal template. 
	# do this directly, don't use calendar_portlet::add_self_to_page here
	set portal_template_id \
		[dotlrn_community::get_portal_template_id $community_id]
	
	calendar_portlet::make_self_available $portal_template_id

	set element_id \
		[portal::add_element $portal_template_id \
		[calendar_portlet::my_name]]

	# set the group_calendar_id parameter in the portal template,
	# which will be copied to every user after this
	portal::set_element_param \
		$element_id "group_calendar_id" $group_calendar_id

	return $package_id
    }

    ad_proc -public remove_applet {
	community_id
	package_id
    } {
	remove the applet from the community
    } {
	# Remove all instances of the calendar portlet! (this is some
	# serious stuff!)
	# Dropping all messages, forums
	# Killing the package
    }

    ad_proc -public add_user {
	community_id
	user_id
    } {
	Called once when a user is added as a dotlrn user
    } {

	ns_log notice "aks91: dotlrn_calendar add_applet called"

	# create a private calendar for this user

	#	set community_name \
	#	"Your Calendar for [dotlrn_community::get_community_name $community_id]"

	# 	set calendar_id [calendar_create $user_id "t" $community_name]

	# add this PE to the user's workspace!
	set workspace_portal_id [dotlrn::get_workspace_portal_id $user_id]

	# Add the portlet here
	calendar_portlet::add_self_to_page $workspace_portal_id $calendar_id
    }

    ad_proc -public add_user_to_community {
	community_id
	user_id
    } {
	Add a user to a community
    } {

	# create a private calendar for the user
	set community_name \
		"Your Calendar for [dotlrn_community::get_community_name $community_id]"

	# aks XXX
	# add the portlet, to this user's community portal
	set portal_id [dotlrn_community::get_portal_id $community_id $user_id]

	# Add the calendar DS to the user's community portal. 
	# This will copy the params from the portal template if exists
	calendar_portlet::make_self_available $portal_id
	calendar_portlet::add_self_to_page $portal_id $calendar_id 	

	# temporary hack by ben to make calendar unique (FIXME)
	set calendar_id [calendar_create $user_id "t" "$community_name-$user_id"]

	# XXX - aks - public calendar params here?

	# XXX we need to make sure that the group_portal_id 
	# for this community gets passed to the user's workspace
	# portal correctly XXX

    }

    ad_proc -public remove_user {
	community_id
	user_id
    } {
	Remove a user from a community
    } {
	# Get the portal_id
	set portal_id [dotlrn_community::get_portal_id $community_id $user_id]
	
	# Get the package_id by callback
	set package_id [dotlrn_community::get_package_id $community_id]

	# Remove the portal element
	calendar_portlet::remove_self_from_page $portal_id $package_id

	# Buh Bye.
	calendar_portlet::make_self_unavailable $portal_id

	# remove user permissions to see calendar folders
	# nothing to do here
    }
	
}
