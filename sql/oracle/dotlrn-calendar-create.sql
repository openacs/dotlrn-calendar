--
--  Copyright (C) 2001, 2002 OpenForce, Inc.
--
--  This file is part of dotLRN.
--
--  dotLRN is free software; you can redistribute it and/or modify it under the
--  terms of the GNU General Public License as published by the Free Software
--  Foundation; either version 2 of the License, or (at your option) any later
--  version.
--
--  dotLRN is distributed in the hope that it will be useful, but WITHOUT ANY
--  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
--  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
--  details.
--

-- The dotlrn-calendar applet's implimentation of the dotlrn applet contract
--
-- ben,arjun@openforce.net
--
-- $Id$
--


declare
	foo integer;
begin
	-- create the implementation
	foo := acs_sc_impl.new (
		'dotlrn_applet',
		'dotlrn_calendar',
		'dotlrn_calendar'
	);

	-- GetPrettyName
	foo := acs_sc_impl.new_alias (
	       'dotlrn_applet',
	       'dotlrn_calendar',
	       'GetPrettyName',
	       'dotlrn_calendar::get_pretty_name',
	       'TCL'
	);

	-- AddApplet
	foo := acs_sc_impl.new_alias (
	       'dotlrn_applet',
	       'dotlrn_calendar',
	       'AddApplet',
	       'dotlrn_calendar::add_applet',
	       'TCL'
	);

	-- RemoveApplet
	foo := acs_sc_impl.new_alias (
	       'dotlrn_applet',
	       'dotlrn_calendar',
	       'RemoveApplet',
	       'dotlrn_calendar::remove_applet',
	       'TCL'
	);

	-- AddAppletToCommunity
	foo := acs_sc_impl.new_alias (
	       'dotlrn_applet',
	       'dotlrn_calendar',
	       'AddAppletToCommunity',
	       'dotlrn_calendar::add_applet_to_community',
	       'TCL'
	);

	-- RemoveAppletFromCommunity
	foo := acs_sc_impl.new_alias (
	       'dotlrn_applet',
	       'dotlrn_calendar',
	       'RemoveAppletFromCommunity',
	       'dotlrn_calendar::remove_applet_from_community',
	       'TCL'
	);

	-- AddUser
	foo := acs_sc_impl.new_alias (
	       'dotlrn_applet',
	       'dotlrn_calendar',
	       'AddUser',
	       'dotlrn_calendar::add_user',
	       'TCL'
	);

	-- RemoveUser
	foo := acs_sc_impl.new_alias (
	       'dotlrn_applet',
	       'dotlrn_calendar',
	       'RemoveUser',
	       'dotlrn_calendar::remove_user',
	       'TCL'
	);

	-- AddUserToCommunity
	foo := acs_sc_impl.new_alias (
	       'dotlrn_applet',
	       'dotlrn_calendar',
	       'AddUserToCommunity',
	       'dotlrn_calendar::add_user_to_community',
	       'TCL'
	);

	-- RemoveUserFromCommunity
	foo := acs_sc_impl.new_alias (
	       'dotlrn_applet',
	       'dotlrn_calendar',
	       'RemoveUserFromCommunity',
	       'dotlrn_calendar::remove_user_from_community',
	       'TCL'
	);

	-- Add the binding
	acs_sc_binding.new (
	    contract_name => 'dotlrn_applet',
	    impl_name => 'dotlrn_calendar'
	);
end;
/
show errors
