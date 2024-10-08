#
#  Copyright (C) 2001, 2002 MIT
#
#  This file is part of dotLRN.
#
#  dotLRN is free software; you can redistribute it and/or modify it under the
#  terms of the GNU General Public License as published by the Free Software
#  Foundation; either version 2 of the License, or (at your option) any later
#  version.
#
#  dotLRN is distributed in the hope that it will be useful, but WITHOUT ANY
#  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
#  details.
#

ad_library {

    The dotLRN applet for calendar.

    @author ben@openforce.net,arjun@openforce.net
    @cvs-id $Id$
}

namespace eval dotlrn_calendar {}

ad_proc -public dotlrn_calendar::package_key {} {
    What package does this applet deal with?
} {
    return "calendar"
}

ad_proc -public dotlrn_calendar::my_package_key {} {
    What's my package key?
} {
    return "dotlrn-calendar"
}

ad_proc -public dotlrn_calendar::applet_key {} {
    What's my applet key?
} {
    return "dotlrn_calendar"
}

ad_proc -public dotlrn_calendar::get_pretty_name {} {
    @return the pretty name
} {
    return "#calendar-portlet.pretty_name#"
}

ad_proc -public dotlrn_calendar::add_applet {} {
    Called for one time init - must be repeatable!
    @return new pkg_id or 0 on failure
} {
    # FIXME: won't work with multiple dotlrn instances
    # Use the package_key for the -url param - "/" are not allowed!
    if {![dotlrn::is_package_mounted -package_key [package_key]]} {
        set package_id [dotlrn::mount_package \
                            -package_key [package_key] \
                            -url [package_key] \
                            -directory_p "t"]

        # We have to store this package_id!
        # This is the package_id for the calendar instantiation of dotLRN
        parameter::set_from_package_key \
            -package_key [my_package_key] \
            -parameter main_calendar_package_id \
            -value $package_id
    }

    dotlrn_applet::add_applet_to_dotlrn -applet_key [applet_key] -package_key [my_package_key]
}

ad_proc -public dotlrn_calendar::remove_applet {} {
    One-time destroy for when the entire applet is removed from
    dotlrn.
} {
    ad_return_complaint 1 "[applet_key] remove_applet not implemented!"
}

ad_proc -public dotlrn_calendar::calendar_create_helper {
    {-community_id:required}
    {-package_id:required}
} {
    A helper proc to create a new public calendar for a community.

    @return the new calendar_id
} {
    set community_name [dotlrn_community::get_community_name $community_id]

    set owner_id [ad_conn user_id]

    set calendar_id [calendar::new \
                         -owner_id $owner_id \
                         -private_p "f" \
                         -calendar_name $community_name \
                         -package_id $package_id]

    #
    # The calendar.new stored procedure will assign "calendar_admin"
    # permission to the creation user. We remove it, as the creation
    # user already has either already admin privileges or in the case
    # of automatic creation, the creation user (-20) does not need it
    #
    permission::revoke -party_id $owner_id -object_id $calendar_id -privilege "calendar_admin"

    return $calendar_id
}

ad_proc -public dotlrn_calendar::add_applet_to_community {
    community_id
} {
    Add the calendar applet to a specific dotlrn community
} {
    set results [add_applet_to_community_helper \
                     -community_id $community_id]
    return [lindex $results 0]
}

ad_proc -public dotlrn_calendar::add_applet_to_community_helper {
    {-community_id:required}
} {
    Add the calendar applet to a specific dotlrn community

    @param community_id
} {
    #
    # ** setup stuff **
    #
    # automount calendar in this community
    set node_id [site_node::get_node_id_from_object_id -object_id [dotlrn_community::get_package_id $community_id]]

    set package_id [dotlrn::mount_package \
                        -parent_node_id $node_id \
                        -package_key [package_key] \
                        -url [package_key] \
                        -directory_p "t"]

    # Break security inheritance for the newly created calendar
    # object to explicitly take the create permission from
    # regular users. In the following steps' admin' is granted to
    # admins and 'read' to regular users.
    permission::set_not_inherit -object_id $package_id

    # mount attachments under calendar, if available
    # attachments requires that dotlrn-fs is already mounted
    if {[apm_package_registered_p attachments]
        && [dotlrn_community::applet_active_p \
                -community_id $community_id \
                -applet_key [dotlrn_fs::applet_key]]} {

        set attachments_node_id [site_node::new \
                                     -name [attachments::get_url] \
                                     -parent_id [site_node::get_node_id_from_object_id \
                                                     -object_id $package_id]]

        site_node::mount \
            -node_id $attachments_node_id \
            -object_id [apm_package_id_from_key attachments]

        set fs_package_id [dotlrn_community::get_applet_package_id \
                               -community_id $community_id \
                               -applet_key [dotlrn_fs::applet_key]]

        # map the fs root folder to the package_id of the new forums pkg
        attachments::map_root_folder \
            -package_id $package_id \
            -folder_id [fs::get_root_folder -package_id $fs_package_id]

    } else {
        ns_log Warning "DOTLRN-CALENDAR: Warning attachments or dotlrn-fs not found!"
    }

    # Here we create the calendar
    set calendar_id [calendar_create_helper -community_id $community_id -package_id $package_id]

    #
    # Administrators of the parent community should also be able to
    # administer this applet in the child community.
    #
    set parent_community_admins [db_string get_admins {
        select segment_id from rel_segments
         where group_id = (select parent_community_id
                             from dotlrn_communities_all
                            where community_id = :community_id)
           and rel_type = 'dotlrn_admin_rel'
    } -default ""]
    if { $parent_community_admins ne ""} {
        permission::grant \
            -party_id $parent_community_admins \
            -object_id $package_id \
            -privilege "admin"
    }

    # Here we have both the calendar ID and the node ID
    # We associate content using portal mapping (ben)
    # This SHOULD NOT work, but it does cause we're
    # reinstantiating calendar
    set calendar_node_url [site_node::get_children -package_key [package_key] -node_id $node_id]
    set calendar_node_id [site_node::get_node_id -url $calendar_node_url]

    site_node_object_map::new \
        -node_id $calendar_node_id \
        -object_id $calendar_id

    # Explicitly grant admin to community admins and read to community members.
    # Admins have full rights on this calendar package then, community members
    # may only read.
    set admin_segment_id [dotlrn_community::get_rel_segment_id \
                              -community_id $community_id \
                              -rel_type dotlrn_admin_rel]
    permission::grant \
        -party_id $admin_segment_id \
        -object_id $package_id \
        -privilege "admin"

    # same thing for reading, cause it's not granted by context_id (ben)
    set members_segment_id [dotlrn_community::get_rel_segment_id \
                                -community_id $community_id \
                                -rel_type dotlrn_member_rel]
    permission::grant \
        -party_id $members_segment_id \
        -object_id $package_id \
        -privilege "read"
    #
    # ** portlet stuff **
    #

    # append the calendar_id to the current portlet
    set calendar_id $calendar_id
    set scoped_p f

    #
    # set up the admin portlet
    #

    set admin_portal_id [dotlrn_community::get_admin_portal_id \
                             -community_id $community_id]

    calendar_admin_portlet::add_self_to_page \
        -portal_id $admin_portal_id \
        -calendar_id $calendar_id

    #
    # set up the Class Schedule Portlet
    #
    # this is an exception to the general "style", but
    # this portlet is only on communities, so we can't
    # put this code in add_portlet_helper

    set portal_id [dotlrn_community::get_portal_id -community_id $community_id]

    calendar_list_portlet::add_self_to_page \
        -portal_id $portal_id \
        -calendar_id $calendar_id \
        -scoped_p $scoped_p

    #
    # set up the calendar and full calendar portlets using add_portlet_helper
    #

    set args [ns_set create]
    ns_set put $args calendar_id $calendar_id
    ns_set put $args scoped_p $scoped_p
    ns_set put $args param_action "overwrite"
    ns_set put $args full_portlet_page_name ""

    dotlrn_calendar::add_portlet_helper $portal_id $args

    # this should return the package_id
    return $package_id
}

ad_proc -public dotlrn_calendar::remove_applet_from_community {
    community_id
} {
    Remove the applet from the community.
} {
    ad_return_complaint 1 "[applet_key] remove_applet_from_community not implemented!"
}

ad_proc -public dotlrn_calendar::add_user {
    user_id
} {
    Called once when a user is added as a dotlrn user.
    Create a private, personal, global calendar for the
    user if they don't have one, and add both calendar portlets
    to the user's portal
} {
    set calendar_id [calendar::have_private_p -return_id 1 -party_id $user_id]

    if {$calendar_id == 0} {
        # HERE we need to find the package ID for the calendar instance at the top level
        # How we do this is a tad tricky
        # set calendar_id [calendar_create $user_id "t" "Personal"]
        set calendar_id [calendar::new \
                             -owner_id $user_id \
                             -private_p "t" \
                             -calendar_name "Personal" \
                             -package_id [parameter::get_from_package_key -package_key [my_package_key] -parameter main_calendar_package_id]]

        # Here we map the calendar to the main dotlrn package
        set node_url [site_node::get_children -package_key [package_key] -node_id [dotlrn::get_node_id]]
        set node_id [site_node::get_node_id -url $node_url]

        site_node_object_map::new -node_id $node_id -object_id $calendar_id
    }

    set args [ns_set create]
    ns_set put $args calendar_id $calendar_id
    ns_set put $args scoped_p "t"

    # Avoid a stale cache
    ::dotlrn::dotlrn_user_cache flush -partition_key $user_id $user_id-portal_id
    dotlrn_calendar::add_portlet_helper \
        [dotlrn::get_portal_id -user_id $user_id] \
        $args
}

ad_proc -public dotlrn_calendar::remove_user {
    user_id
} {
    Remove a user from dotlrn

    @author Deds Castillo (deds@i-manila.com.ph)
    @creation-date 2004-08-12
} {
    # reverse the things done by add_user
    set calendar_id [calendar::have_private_p -return_id 1 -party_id $user_id]

    if {$calendar_id} {
        calendar::get -calendar_id $calendar_id -array calendar_info
        set dotlrn_calendar_package_id [parameter::get_from_package_key -package_key [my_package_key] -parameter main_calendar_package_id]

        # make sure the calendar we got belong to the package in
        # dotlrn or we may end up deleting some other calendar
        if {$calendar_info(package_id) == $dotlrn_calendar_package_id} {
            # remove the mapping
            site_node_object_map::del -object_id $calendar_id
            # remove the calendar
            calendar::delete -calendar_id $calendar_id
        }
    }
}

ad_proc -public dotlrn_calendar::add_user_to_community {
    community_id
    user_id
} {
    Add a user to a community
} {
    set calendar_id [get_group_calendar_id -community_id $community_id]
    set portal_id [dotlrn::get_portal_id -user_id $user_id]

    set args [ns_set create]
    ns_set put $args calendar_id $calendar_id
    ns_set put $args param_action "append"

    dotlrn_calendar::add_portlet_helper $portal_id $args
}

ad_proc -public dotlrn_calendar::remove_user_from_community {
    community_id
    user_id
} {
    Remove a user from a community
} {
    set calendar_id [get_group_calendar_id -community_id $community_id]
    set portal_id [dotlrn::get_portal_id -user_id $user_id]

    set args [ns_set create]
    ns_set put $args calendar_id $calendar_id

    dotlrn_calendar::remove_portlet $portal_id $args
}

ad_proc -public dotlrn_calendar::add_portlet {
    portal_id
} {
    Set up default params for templates about to call add_portlet_helper

    @param portal_id
} {
    set type [dotlrn::get_type_from_portal_id -portal_id $portal_id]

    set args [ns_set create]
    ns_set put $args calendar_id 0
    ns_set put $args full_portlet_page_name [get_default_page $type]
    ns_set put $args scoped_p f

    if {$type eq "user"} {
        # the portlet has a special name on a user portal
        ns_set put $args pretty_name "#dotlrn-calendar.Day_Summary#"
        ns_set put $args scoped_p t
    }  else {
        # add this portlet to all types of communities
        calendar_list_portlet::add_self_to_page \
            -portal_id $portal_id \
            -calendar_id 0 \
            -scoped_p f
    }

    add_portlet_helper $portal_id $args
}

ad_proc -private dotlrn_calendar::add_portlet_helper {
    portal_id
    args
} {
    Does the call to add the portlet to the portal.
    Params for the portlet are sent to this proc by the caller.
} {
    calendar_portlet::add_self_to_page \
        -portal_id $portal_id \
        -pretty_name [ns_set get $args "pretty_name"] \
        -calendar_id [ns_set get $args "calendar_id"]  \
        -scoped_p [ns_set get $args "scoped_p"] \
        -param_action [ns_set get $args "param_action"]

    calendar_full_portlet::add_self_to_page \
        -portal_id $portal_id \
        -page_name [ns_set get $args "full_portlet_page_name"] \
        -calendar_id [ns_set get $args "calendar_id"]  \
        -scoped_p [ns_set get $args "scoped_p"] \
        -param_action [ns_set get $args "param_action"]
}

ad_proc -public dotlrn_calendar::remove_portlet {
    portal_id
    args
} {
    A helper proc to remove the underlying portlet from the given portal.
    This is a lot simpler than add_portlet.

    @param portal_id
    @param args An ns_set with the calendar_id.
} {
    calendar_portlet::remove_self_from_page \
        -portal_id $portal_id \
        -calendar_id [ns_set get $args "calendar_id"]

    calendar_full_portlet::remove_self_from_page \
        -portal_id $portal_id \
        -calendar_id [ns_set get $args "calendar_id"]
}

ad_proc -public dotlrn_calendar::clone {
    old_community_id
    new_community_id
} {
    Clone this applet's content from the old community to the new one
} {
    ns_log notice "Cloning: [applet_key]"

    # copy the old_comm's item types table
    set old_calendar_id [get_group_calendar_id \
                             -community_id $old_community_id]

    add_applet_to_community_helper \
        -community_id $new_community_id

    set calendar_id [get_group_calendar_id \
                         -community_id $new_community_id]

    db_dml copy_cal_item_types {}
}

ad_proc -public dotlrn_calendar::change_event_handler {
    community_id
    event
    old_value
    new_value
} {
    Listens for the following events: rename
} {
    switch $event {
        rename {
            handle_rename -community_id $community_id -old_value $old_value -new_value $new_value
        }
    }
}

ad_proc -private dotlrn_calendar::handle_rename {
    {-community_id:required}
    {-old_value:required}
    {-new_value:required}
} {
    what to do in calendar when a dotlrn community is renamed
} {
    calendar::rename -calendar_id [get_group_calendar_id -community_id $community_id] -calendar_name $new_value
}

#
# Some dotlrn_calendar specific procs
#

ad_proc -public dotlrn_calendar::get_group_calendar_id {
    {-community_id:required}
} {
    Find the group_calendar_id for the given community
} {
    set portal_id [dotlrn_community::get_portal_id \
                       -community_id $community_id]

    # get the calendar element for this community
    set element_id [portal::get_element_ids_by_ds \
                        $portal_id \
                        [calendar_portlet::get_my_name]]

    return [portal::get_element_param $element_id "calendar_id"]
}

ad_proc -private dotlrn_calendar::get_default_page { portal_type } {
    The pretty name of the page to add the portlet to.
} {
    switch $portal_type {
        user {
            set page_name "#dotlrn.user_portal_page_calendar_title#"
        }
        dotlrn_community {
            set page_name "#dotlrn.subcomm_page_calendar_title#"
        }
        dotlrn_class_instance {
            set page_name "#dotlrn.class_page_calendar_title#"
        }
        dotlrn_club {
            set page_name "#dotlrn.club_page_calendar_title#"
        }
        default {
            ns_log Error "dotlrn-calendar applet: Don't know page name to add portlet to for portal type $portal_type"
        }
    }

    return $page_name
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
