
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

    ad_proc -public applet_key {} {
        return "dotlrn_calendar"
    }
    
    ad_proc -public get_url {
    } {
	get the package_key this applet deals with
    } {
	return "/[package_key]"
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

    ad_proc -public get_user_default_page {} {
        return the user default page to add the portlet to
    } {
        return [ad_parameter -package_id [apm_package_id_from_key dotlrn-calendar] user_default_page]
    }

    ad_proc -public add_applet {
    } {
	Called for one time init - must be repeatable!
	@return new pkg_id or 0 on failure
    } {
	# FIXME: won't work with multiple dotlrn instances 
        # Use the package_key for the -url param - "/" are not allowed!
	if {![dotlrn::is_package_mounted -package_key [package_key]]} {
            dotlrn::mount_package \
                    -package_key [package_key] \
                    -url [package_key] \
                    -directory_p "t"
	}

        # register/activate self with dotlrn
        # our service contract is in the db, but we must tell dotlrn
        # that we exist and want to be active
        dotlrn_community::add_applet_to_dotlrn -applet_key [applet_key]
    }

    ad_proc -public add_applet_to_community {
	community_id
    } {
	Add the calendar applet to a specific dotlrn community
    } {
	# set up a nice name for the comm's calendar
	set cal_name  "[dotlrn_community::get_community_name $community_id] Public Calendar"

	# create the community's calendar, the "f" is for a public calendar
	set group_calendar_id \
		[calendar_create [ad_conn "user_id"] "f" $cal_name]

        ns_log notice "aks14 $cal_name: group_calendar_id $group_calendar_id"

	# add this element to the portal template. 
	# do this directly, don't use calendar_portlet::add_self_to_page here
	set portal_template_id \
		[dotlrn_community::get_portal_template_id $community_id]
	
	calendar_portlet::make_self_available $portal_template_id

	set element_id \
		[portal::add_element $portal_template_id \
		[calendar_portlet::my_name]]

	# set the group_calendar_id parameter in the portal template,
	portal::set_element_param \
		$element_id "calendar_id" $group_calendar_id

        # Add the admin portlet, too
	set admin_portal_id \
		[dotlrn_community::get_community_admin_portal_id $community_id]
	
	calendar_admin_portlet::make_self_available $admin_portal_id

	set element_id \
		[portal::add_element $admin_portal_id \
		[calendar_admin_portlet::my_name]]

        # automount calendar in this community
        set node_id [site_nodes::get_node_id_from_url \
                -url [dotlrn_community::get_url_from_package_id \
                -package_id [dotlrn_community::get_package_id $community_id]]]
        
        set package_id [dotlrn::mount_package \
                -parent_node_id $node_id \
                -package_key [package_key] \
                -url [package_key] \
                -directory_p "t"]
        
        # Becase the context_id of calendar dosen't point to the community
        # the calendar_admin perm is not automatically inherited (like
        # in bboard for example) We must do an explicit grant to the
        # dotlrn_admin_rel relational segment. dotlrn_ta_rel and dotlrn_instructor_rel
        # both inherit from the dotlrn_admin_rel, so we don't have to grant to them.

	set admin_segment_id [dotlrn_community::get_rel_segment_id -community_id $community_id -rel_type dotlrn_admin_rel]
	ad_permission_grant $admin_segment_id $group_calendar_id admin
        # ns_log notice "aks16 granted"

        # same thing for reading, cause it's not granted by context_id (ben)
        set members_segment_id [dotlrn_community::get_rel_segment_id -community_id $community_id -rel_type dotlrn_member_rel]
        ad_permission_grant $members_segment_id $group_calendar_id read

	return $group_calendar_id
    }

    ad_proc -public remove_applet {
	community_id
	package_id
    } {
	remove the applet from the community
    } {
        # XXX 

	# Remove all instances of the calendar portlet! (this is some
	# serious stuff!)
	# Dropping all messages, forums
	# Killing the package
    }

    ad_proc -public add_user {
	user_id
    } {
	Called once when a user is added as a dotlrn user
    } {
        # this is lame, but I can't find a proc to do this
        set user_name [db_string user_name_select {
	select first_names || ' ' || last_name as name
	from persons
	where person_id = :user_id
        }]

	# create a private, global calendar for this user
	set cal_name "$user_name's Personal Calendar"
 	set calendar_id [calendar_create $user_id "t" $cal_name]

	# add this PE to the user's workspace!
	set workspace_portal_id [dotlrn::get_workspace_portal_id $user_id]

	# Add the portlet here
        if { $workspace_portal_id != "" } {
            calendar_portlet::make_self_available $workspace_portal_id

            # (ben) I changed this to be added to the front page now, because
            # the one we're adding to calendar is the full calendar thing, not the summary
            set element_id  [calendar_portlet::add_self_to_page \
                    $workspace_portal_id \
                    $calendar_id]

            set element_id [calendar_full_portlet::add_self_to_page \
                    -page_id [portal::get_page_id -portal_id $workspace_portal_id \
                    -page_name [get_user_default_page]] \
                    $workspace_portal_id \
                    $calendar_id]
        }

    }

    ad_proc -public add_user_to_community {
	community_id
	user_id
    } {
	Add a user to a community
    } {
        # Get the portal_id by callback
	set portal_id [dotlrn_community::get_portal_id $community_id $user_id]

        # get the group_calendar_id by callback
        set g_cal_id [portal::get_element_param \
                [lindex [portal::get_element_ids_by_ds \
                [portal::get_portal_template_id $portal_id] \
                [calendar_portlet::my_name]] 0] \
                "calendar_id"]

	# Make the calendar DS available to this page
	calendar_portlet::make_self_available $portal_id

	# Call the portal element to be added correctly
	calendar_portlet::add_self_to_page \
                $portal_id $g_cal_id


	# Now for the user workspace
	# set this calendar_id in the workspace portal
        set workspace_portal_id [dotlrn::get_workspace_portal_id $user_id]
        
        # get the comm's calendar_id, and add it as a param to the
        # ws portal's calendar portal element
        if { $workspace_portal_id != "" } {
            calendar_portlet::add_self_to_page $workspace_portal_id $g_cal_id

            calendar_full_portlet::add_self_to_page $workspace_portal_id $g_cal_id
        }

        # Ben's fix: we do NOT assign permissions individually
        # This means I have to go fix the way permissions are assigned
        # at applet creation time (ben)
        #
        # aks debug 
        # ns_log notice "aks13 $user_id $g_cal_id calendar_read"
	# ad_permission_grant $user_id $g_cal_id calendar_read        
	# ad_permission_grant $user_id $g_cal_id calendar_show        
        # ns_log notice "aks14 read + show granted to user $user_id and cal $g_cal_id"

    }

    ad_proc -public remove_user {
        user_id
    } {
        Remove a user entirely
    } {
        # FIXME: nothing for now
    }

    ad_proc -public remove_user_from_community {
	community_id
	user_id
    } {
	Remove a user from a community
    } {
	# Get the portal_id
	set portal_id [dotlrn_community::get_portal_id $community_id $user_id]
	
	# Get the package_id by callback
	set package_id [dotlrn_community::get_applet_package_id $community_id [applet_key]]

	# Remove the portal element
	calendar_portlet::remove_self_from_page $portal_id $package_id

	# Buh Bye.
	calendar_portlet::make_self_unavailable $portal_id

        # Remove from main workspace
        set workspace_portal_id [dotlrn::get_workspace_portal_id $user_id]

        # Remove the portlet
        if {![empty_string_p $workspace_portal_id]} {
            calendar_portlet::remove_self_from_page $workspace_portal_id $package_id
            calendar_full_portlet::remove_self_from_page $workspace_portal_id $package_id
        }
    }

    #
    # Some dotlrn_calendar specific procs
    # 
    
    ad_proc -public get_group_calendar_id {
        {-community_id:required}
    } {
        Find the group_calendar_id for the given community
    } {

        # get the portal_template_id for this comm
        set portal_template_id [dotlrn_community::get_portal_template_id $community_id]

        # get the calendar element for this community
        set element_id [portal::get_element_ids_by_ds \
                $portal_template_id \
                [calendar_portlet::my_name]]

        #  [lindex element_ids 0] 
        return [portal::get_element_param $element_id "calendar_id"]
    }



}
