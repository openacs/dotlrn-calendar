
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
	community_id
    } {
	Add the calendar applet
    } {
	# create the calendar package instance (all in one, I've mounted it)
	set package_key [package_key]
	set package_id [dotlrn::instantiate_and_mount $community_id $package_key]

	# first get the community name from dotlrn
	set community_name "The [dotlrn_community::get_community_name] Calendar"
	
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
	Add a user to a community
    } {
	set page_id [dotlrn_community::get_page_id $community_id $user_id]
	set package_id [dotlrn_community::get_applet_package_id \
		$community_id dotlrn_calendar]

	# create a private calendar for the user
	set community_name \
		"Your Calendar for [dotlrn_community::get_community_name]"

	# temporary hack by ben to make calendar unique (FIXME)
	set calendar_id [calendar_create $user_id "t" "$community_name-$user_id"]

	# XXX - aks - public calendar params here?

	# Add the calendar DS to the user's portal. 
	calendar_portlet::make_self_available $page_id

	# This will copy the params from the portal template if exists
	calendar_portlet::add_self_to_page $page_id $calendar_id 
    }

    ad_proc -public remove_user {
	community_id
	user_id
    } {
	Remove a user from a community
    } {
	# Get the page_id
	set page_id [dotlrn_community::get_page_id $community_id $user_id]
	
	# Get the package_id by callback
	set package_id [dotlrn_community::get_package_id $community_id]

	# Remove the portal element
	calendar_portlet::remove_self_from_page $page_id $package_id

	# Buh Bye.
	calendar_portlet::make_self_unavailable $page_id

	# remove user permissions to see calendar folders
	# nothing to do here
    }
	
}
