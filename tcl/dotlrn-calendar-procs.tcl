#
#  Copyright (C) 2001, 2002 OpenForce, Inc.
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

    TCL implimentation of the dotlrn applet contract for calendar

    @author ben@openforce.net,arjun@openforce.net
    @version $Id$
}

namespace eval dotlrn_calendar {

    ad_proc -public package_key {
    } {
        the package_key this applet deals with
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
        return "Calendar"
    }

    ad_proc -public get_user_default_page {} {
        return the user default page to add the portlet to
    } {
        # there shouldn't need to be a default here, but this 
        # call is not working for some reason
        return [ad_parameter "user_default_page" dotlrn-calendar "Calendar"]
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
        dotlrn_applet::add_applet_to_dotlrn -applet_key [applet_key]
    }

    ad_proc -public remove_applet {
    } {
        One-time destroy for when the entire applet is removed from dotlrn. 
    } {
        return
    }

    ad_proc -public add_applet_to_community {
        community_id
    } {
        Add the calendar applet to a specific dotlrn community
    } {
        # add this element to the community portal
        # do this directly, don't use calendar_portlet::add_self_to_page here

        # aks: why direct??
        set portal_id [dotlrn_community::get_portal_id -community_id $community_id]

        set element_id [portal::add_element \
                -pretty_name [get_pretty_name] \
                -force_region 2 \
                -portal_id $portal_id \
                -portlet_name [calendar_portlet::get_my_name]
        ]

        # add the "full calendar" portlet to the commnuity's "calendar" page,
        # similar to the same thing on a user's wsp. use the get_user_def_page
        set page_name [get_user_default_page]
        if {[dotlrn_community::dummy_comm_p -community_id $community_id]} {
            # since this is a dummy comm, set a fake g_cal_id
            set element_id [calendar_full_portlet::add_self_to_page \
                -portal_id $portal_id \
                -page_name $page_name \
                -calendar_id 0
            ]
            return
        }

        # create the community's calendar, the "f" is for a public calendar
        set group_calendar_id [calendar_create \
                [ad_conn "user_id"] \
                "f" \
                "[dotlrn_community::get_community_name $community_id]"
        ]

        # set the group_calendar_id parameter in the comm's portal
        portal::set_element_param \
                $element_id "calendar_id" $group_calendar_id

        # This is not scoped, because we are only seeing one group calendar
        portal::set_element_param \
                $element_id "scoped_p" "f"

        set element_id [calendar_full_portlet::add_self_to_page \
                -portal_id $portal_id \
                -page_name $page_name  \
                -calendar_id $group_calendar_id
        ]

        # Add the admin portlet, too
        set admin_portal_id [dotlrn_community::get_admin_portal_id -community_id $community_id]

        set element_id [portal::add_element \
                -portal_id $admin_portal_id \
                -portlet_name [calendar_admin_portlet::get_my_name]
        ]

        # set the group_calendar_id parameter in the admin portal.
        portal::set_element_param \
                $element_id "calendar_id" $group_calendar_id

        # automount calendar in this community
        set node_id [site_nodes::get_node_id_from_url \
                -url [dotlrn_community::get_url_from_package_id \
                -package_id [dotlrn_community::get_package_id $community_id]]]

        set package_id [dotlrn::mount_package \
                -parent_node_id $node_id \
                -package_key [package_key] \
                -url [package_key] \
                -directory_p "t"]

        # Here we have both the calendar ID and the node ID
        # We associate content using portal mapping (ben)
        # This SHOULD NOT work, but it does cause we're 
        # reinstantiating calendar
        portal::mapping::new \
                -node_id \
                [site_nodes::get_node_id_from_child_name \
                    -parent_node_id $node_id \
                    -name [package_key]] \
                -object_id $group_calendar_id

        # Becase the context_id of calendar dosen't point to the community
        # the calendar_admin perm is not automatically inherited (like
        # in bboard for example) We must do an explicit grant to the
        # dotlrn_admin_rel relational segment. dotlrn_ta_rel and dotlrn_instructor_rel
        # both inherit from the dotlrn_admin_rel, so we don't have to grant to them.

        set admin_segment_id [dotlrn_community::get_rel_segment_id \
                -community_id $community_id \
                -rel_type dotlrn_admin_rel
        ]
        permission::grant \
                -party_id $admin_segment_id \
                -object_id $group_calendar_id \
                -privilege "admin"

        # same thing for reading, cause it's not granted by context_id (ben)
        set members_segment_id [dotlrn_community::get_rel_segment_id \
                -community_id $community_id \
                -rel_type dotlrn_member_rel
        ]
        permission::grant \
                -party_id $members_segment_id \
                -object_id $group_calendar_id \
                -privilege "read"

        # this should return the package_id
        return $package_id
    }

    ad_proc -public remove_applet_from_community {
        community_id
    } {
        remove the applet from the community
    } {        
        set group_calendar_id [get_group_calendar_id -community_id $community_id]

        # first, revoke the permissions
        set members_segment_id [dotlrn_community::get_rel_segment_id \
                -community_id $community_id \
                -rel_type dotlrn_member_rel
        ]
        set admin_segment_id [dotlrn_community::get_rel_segment_id \
                -community_id $community_id \
                -rel_type dotlrn_admin_rel
        ]
        
        permission::revoke \
                -party_id $members_segment_id \
                -object_id $group_calendar_id \
                -privilege "read"

        permission::revoke \
                -party_id $admin_segment_id \
                -object_id $group_calendar_id \
                -privilege "admin"

        # delete the "portal node mapping"
        portal::mapping::del -object_id $group_calendar_id

        # remove the portlets, params will cascade
        # first the admin portlet, from the comm's admin portal
        set admin_portal_id [dotlrn_community::get_admin_portal_id \
                                 -community_id $community_id
        ]

        portal::remove_element \
            -portal_id $admin_portal_id \
            -portlet_name [calendar_admin_portlet::get_my_name]

        # now for the "regular" calendar portlet from the comm's portal
        set portal_id [dotlrn_community::get_portal_id -community_id $community_id]

        # now for the "full calendar" portlet from the comm's portal
        portal::remove_element \
            -portal_id $portal_id \
            -portlet_name [calendar_full_portlet::get_my_name]
        
        # and finally kill the group calendar
        calendar_delete -calendar_id $group_calendar_id

        # delete the package instance and the site node where it's mounted
        dotlrn::unmount_community_applet_package \
            -community_id $community_id \
            -package_key [package_key]
    }

    ad_proc -public add_user {
        user_id
    } {
        Called once when a user is added as a dotlrn user
    } {
        set calendar_id [calendar_have_private_p -return_id 1 $user_id]

        # if the user already has a personal calendar in the system
        # don't make a new one
        
        if {$calendar_id == 0} {
            # this is lame, but I can't find a proc to do this
#              set user_name [db_string user_name_select "
#                  select first_names || ' ' || last_name as name
#                  from persons
#                  where person_id = :user_id
#              "]

            # create a private, global calendar for this user
            set cal_name "Personal"
            set calendar_id [calendar_create $user_id "t" $cal_name]

            # Here we map the calendar to the main dotlrn package
            set node_id [site_nodes::get_node_id_from_child_name \
                    -parent_node_id [dotlrn::get_node_id] \
                    -name [package_key]
            ]
            
            portal::mapping::new -node_id $node_id -object_id $calendar_id
        }

        set workspace_portal_id [dotlrn::get_workspace_portal_id $user_id]
      
        # add the "day summary" pe to the user's first workspace page
        set element_id [calendar_portlet::add_self_to_page \
            -portal_id $workspace_portal_id \
            -calendar_id $calendar_id \
        ]

        # but add the "full calendar" pe to the workspace page specified above
        set element_id [calendar_full_portlet::add_self_to_page \
            -portal_id $workspace_portal_id \
            -page_name [get_user_default_page] \
            -calendar_id $calendar_id
        ]

        # Make sure this is scoped
        portal::set_element_param $element_id scoped_p t
    }

    ad_proc -public remove_user {
        user_id
    } {
        Remove a user entirely
    } {
        # FIXME - not tested
        set portal_id [dotlrn::get_workspace_portal_id $user_id]
        set calendar_id [calendar_have_private_p -return_id 1 $user_id]

        set args [ns_set create args]
        ns_set put $args user_id $user_id
        ns_set put $args calendar_id $calendar_id
        set list_args [list $portal_id $args]

        remove_portlet $portal_id $args
    }

    ad_proc -public add_user_to_community {
        community_id
        user_id
    } {
        Add a user to a community
    } {
        set g_cal_id [get_group_calendar_id -community_id $community_id]
        set workspace_portal_id [dotlrn::get_workspace_portal_id $user_id]

        calendar_portlet::add_self_to_page \
            -portal_id $workspace_portal_id \
            -calendar_id $g_cal_id

        calendar_full_portlet::add_self_to_page \
            -portal_id $workspace_portal_id \
            -calendar_id $g_cal_id
    }

    ad_proc -public remove_user_from_community {
        community_id
        user_id
    } {
        Remove a user from a community
    } {
        set portal_id [dotlrn::get_workspace_portal_id $user_id]
        set calendar_id [get_group_calendar_id -community_id $community_id]

        set args [ns_set create args]
        ns_set put $args user_id $user_id
        ns_set put $args community_id $community_id
        ns_set put $args calendar_id $calendar_id
        set list_args [list $portal_id $args]

        remove_portlet $portal_id $args
    }

    ad_proc -public add_portlet {
        args
    } {
        A helper proc to add the underlying portlet to the given portal. 
        
        @param args a list-ified array of args defined in add_applet_to_community
    } {
        ns_log notice "** Error in [get_pretty_name]: 'add_portlet' not implemented!"
        ad_return_complaint 1  "Please notifiy the administrator of this error:
        ** Error in [get_pretty_name]: 'add_portlet' not implemented!"
    }

    ad_proc -public remove_portlet {
        portal_id
        args
    } {
        A helper proc to remove the underlying portlet from the given portal. 
        
        @param portal_id
        @param args A list of key-value pairs (possibly user_id, community_id, and more)
    } { 
        set user_id [ns_set get $args "user_id"]
        set community_id [ns_set get $args "community_id"]

        if {![empty_string_p $user_id]} {
            # the portal_id is a user's portal
            set calendar_id [ns_set get $args "calendar_id"]
        } elseif {![empty_string_p $community_id]} {
            # the portal_id is a community portal
            ad_return_complaint 1  "dotlrn_calendar aks1 unimplimented"
        } else {
            # the portal_id is a portal template
            ad_return_complaint 1  "dotlrn_calendar aks2 unimplimented"
        }

        calendar_portlet::remove_self_from_page $portal_id $calendar_id
        calendar_full_portlet::remove_self_from_page $portal_id $calendar_id
    }

    ad_proc -public clone {
        old_community_id
        new_community_id
    } {
        Clone this applet's content from the old community to the new one
    } {
        ns_log notice "** Error in [get_pretty_name] 'clone' not implemented!"
        ad_return_complaint 1  "Please notifiy the administrator of this error:
        ** Error in [get_pretty_name]: 'clone' not implemented!"
    }

    #
    # Some dotlrn_calendar specific procs
    #

    ad_proc -public get_group_calendar_id {
        {-community_id:required}
    } {
        Find the group_calendar_id for the given community
    } {
        set portal_id [dotlrn_community::get_portal_id \
                -community_id $community_id
        ]

        # get the calendar element for this community
        set element_id [portal::get_element_ids_by_ds \
                $portal_id \
                [calendar_portlet::get_my_name]
        ]

        return [portal::get_element_param $element_id "calendar_id"]
    }

}
