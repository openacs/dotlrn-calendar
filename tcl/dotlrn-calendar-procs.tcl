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

    the dotlrn applet for calendar

    @author ben@openforce.net,arjun@openforce.net
    @version $Id$
}

namespace eval dotlrn_calendar {

    ad_proc -public package_key {
    } {
        What package does this applet deal with?
    } {
        return "calendar"
    }

    ad_proc -public my_package_key {
    } {
        What's my package key?
    } {
        return "dotlrn-calendar"
    }

    ad_proc -public applet_key {
    } {
        What's my applet key?
    } {
        return "dotlrn_calendar"
    }

    ad_proc -public get_pretty_name {
    } {
    } {
        return "Calendar"
    }

    ad_proc -public add_applet {
    } {
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

        dotlrn_applet::add_applet_to_dotlrn -applet_key [applet_key]
    }

    ad_proc -public remove_applet {
    } {
        One-time destroy for when the entire applet is removed from dotlrn. 
    } {
        ad_return_complaint 1 "[applet_key] remove_applet not implimented!"
    }

    ad_proc -public calendar_create_helper {
        {-community_id:required}
        {-package_id:required}
    } {
        A helper proc to create a calendar for a comm, returns the new calendar_id
    } {
        # create the community's calendar, the "f" is for a public calendar
        set community_name [dotlrn_community::get_community_name $community_id]
        # return [calendar_create [ad_conn "user_id"] "f" $community_name]

        # New calendar proc
        return [calendar::new \
                -owner_id [ad_conn user_id] \
                -private_p "f" \
                -calendar_name $community_name \
                -package_id $package_id]
    }

    ad_proc -public add_applet_to_community {
        community_id
    } {
        Add the calendar applet to a specific dotlrn community
    } {
        set results [add_applet_to_community_helper \
                    -community_id $community_id
        ]
        
        return [lindex $results 0]
    }

    ad_proc -public add_applet_to_community_helper {
        {-community_id:required}
    } {
        Add the calendar applet to a specific dotlrn community

        @params community_id 
    } {
        #
        # ** setup stuff **
        #
        # automount calendar in this community
        set node_id [site_nodes::get_node_id_from_url \
                -url [dotlrn_community::get_url_from_package_id \
                -package_id [dotlrn_community::get_package_id $community_id]]]

        set package_id [dotlrn::mount_package \
                -parent_node_id $node_id \
                -package_key [package_key] \
                -url [package_key] \
                -directory_p "t"]

        # Here we create the calendar
        set calendar_id [calendar_create_helper -community_id $community_id -package_id $package_id]

        # Here we have both the calendar ID and the node ID
        # We associate content using portal mapping (ben)
        # This SHOULD NOT work, but it does cause we're 
        # reinstantiating calendar
        site_node_object_map::new \
                -node_id \
                [site_nodes::get_node_id_from_child_name \
                    -parent_node_id $node_id \
                    -name [package_key]] \
                -object_id $calendar_id

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
                -object_id $calendar_id \
                -privilege "admin"

        # same thing for reading, cause it's not granted by context_id (ben)
        set members_segment_id [dotlrn_community::get_rel_segment_id \
                -community_id $community_id \
                -rel_type dotlrn_member_rel
        ]
        permission::grant \
                -party_id $members_segment_id \
                -object_id $calendar_id \
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
                                 -community_id $community_id
        ]
                
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

    ad_proc -public remove_applet_from_community {
        community_id
    } {
        remove the applet from the community
    } {        
        ad_return_complaint 1 "[applet_key] remove_applet_from_community not implimented!"
    }

    ad_proc -public add_user {
        user_id
    } {
        Called once when a user is added as a dotlrn user.
        Create a priivate, personal, global calendar for the
        user if they don't have one, and add both calendar portlets
        to the user's portal
    } {
        set calendar_id [calendar_have_private_p -return_id 1 $user_id]
        
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
            set node_id [site_nodes::get_node_id_from_child_name \
                    -parent_node_id [dotlrn::get_node_id] \
                    -name [package_key]
            ]
            
            site_node_object_map::new -node_id $node_id -object_id $calendar_id
        }

        set args [ns_set create]
        ns_set put $args calendar_id $calendar_id
        ns_set put $args scoped_p "t"
        
        # don't use the cached version
        dotlrn_calendar::add_portlet_helper \
            [dotlrn::get_portal_id_not_cached -user_id $user_id] \
            $args
    }

    ad_proc -public remove_user {
        user_id
    } {
        Remove a user from dotlrn
    } {
        ad_return_complaint 1 "[applet_key] remove_user not implimented!"
    }

    ad_proc -public add_user_to_community {
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

    ad_proc -public remove_user_from_community {
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

    ad_proc -public add_portlet {
        portal_id
    } {
        Set up default params for templates about to call add_portlet_helper
        
        @param portal_id
    } {
        set args [ns_set create]
        ns_set put $args calendar_id 0
        ns_set put $args full_portlet_page_name [get_community_default_page]
        ns_set put $args scoped_p f

        set type [dotlrn::get_type_from_portal_id -portal_id $portal_id]
        
        if {[string equal $type "user"]} {
            # the portlet has a special name on a user portal
            ns_set put $args pretty_name "Day Summary"
            ns_set put $args full_portlet_page_name [get_user_default_page]
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

    ad_proc -private add_portlet_helper {
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

    ad_proc -public remove_portlet {
        portal_id
        args
    } {
        A helper proc to remove the underlying portlet from the given portal. 
        This is alot simpler than add_portlet.

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

    ad_proc -public clone {
        old_community_id
        new_community_id
    } {
        Clone this applet's content from the old community to the new one
    } {
        ns_log notice "Cloning: [applet_key]"

        # copy the old_comm's item types table
        set old_calendar_id [get_group_calendar_id \
            -community_id $old_community_id
        ]
        
        set results [add_applet_to_community_helper \
                    -community_id $new_community_id
        ]

        set calendar_id [lindex $results 1]

        db_dml copy_cal_item_types {}
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

    ad_proc -public get_user_default_page {} {
        The "full calendar" portlet must go on this page of a user's portal
    } {
        return [parameter::get_from_package_key \
                    -package_key [my_package_key] \
                    -parameter "user_default_page"
        ]
    }

    ad_proc -public get_community_default_page {} {
        The "full calendar" portlet must go on this page of a comm's portal
    } {
        return [parameter::get_from_package_key \
                    -package_key [my_package_key] \
                    -parameter "user_default_page"
        ]
    }
}
