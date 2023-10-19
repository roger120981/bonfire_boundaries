defmodule Bonfire.Boundaries.Web.MyAclsLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.Boundaries.Acls
  alias Bonfire.Boundaries.Grants
  # alias Bonfire.Boundaries.Web.AclLive
  alias Bonfire.Boundaries.LiveHandler

  prop hide_breakdown, :boolean, default: false
  prop setting_boundaries, :boolean, default: false
  prop click_override, :boolean, default: false
  prop to_boundaries, :any, default: nil
  prop to_boundaries_ids, :list, default: []
  prop built_ins, :list, default: []
  prop section, :any, default: nil
  prop edit_acl_id, :string, default: nil
  prop scope, :any, default: nil

  def update(
        %{scope: scope} = assigns,
        %{assigns: %{loaded: true, scope: existing_scope}} = socket
      )
      when scope == existing_scope do
    {:ok,
     assign(
       socket,
       assigns
     )}
  end

  def update(assigns, socket) do
    built_in_ids = Acls.built_in_ids()

    socket =
      socket
      |> assign(assigns)
      |> assign(:built_in_ids, built_in_ids)

    scope = LiveHandler.scope_origin(socket)

    %{page_info: page_info, edges: acls} = my_acls_paginated(scope, socket.assigns)

    {:ok,
     socket
     |> assign(
       loaded: true,
       acls: acls,
       page_info: page_info,
       section: :acls,
       # built_ins: Bonfire.Boundaries.Acls.list_built_ins,
       settings_section_title: "Create and manage your boundaries",
       settings_section_description: "Create and manage your boundaries."
     )}
  end

  def handle_event("load_more", attrs, socket) do
    scope = LiveHandler.scope_origin(socket)

    %{page_info: page_info, edges: edges} =
      my_acls_paginated(scope, socket.assigns, input_to_atoms(attrs))

    {:noreply,
     socket
     |> assign(
       loaded: true,
       acls: e(socket.assigns, :acls, []) ++ edges,
       page_info: page_info
     )}
  end

  def do_handle_event("boundary_edit", %{"id" => id}, socket) do
    debug(id, "boundary_edit")

    {:noreply, assign(socket, :edit_acl_id, id)}
  end

  # TODO
  def do_handle_event("back", _, socket) do
    {:noreply,
     socket
     |> assign(:edit_acl_id, nil)
     |> assign(:section, nil)}
  end

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__,
          &do_handle_event/3
        )

  def my_acls_paginated(scope, assigns, attrs \\ nil) do
    built_in_ids = e(assigns, :built_in_ids, nil) || Acls.built_in_ids()

    {scoped, args} =
      if e(assigns, :setting_boundaries, nil) do
        {scope, Acls.opts_for_dropdown()}
      else
        {
          scope,
          # Acls.opts_for_list()
          [exclude_ids: built_in_ids]
        }

        # if scope == :instance and
        #      Bonfire.Boundaries.can?(assigns, :grant, :instance) do
        #   {
        #     Bonfire.Boundaries.Fixtures.admin_circle(),
        #     [extra_ids_to_include: built_in_ids]
        #   }
        # else
        #   {
        #     current_user,
        #     # Acls.opts_for_list()
        #     [exclude_ids: built_in_ids]
        #   }
        # end
      end

    acls = Acls.list_my_with_counts(scoped, args)

    acls =
      if e(assigns, :hide_breakdown, nil),
        do: acls,
        else:
          repo().maybe_preload(
            acls,
            grants: [
              :verb,
              subject: [
                :named,
                :profile,
                encircle_subjects: [:profile],
                stereotyped: [:named]
              ]
            ]
          )

    debug(acls, "Acls")

    # acls |> Ecto.assoc(:grants) |> repo().aggregate(:count, :id)
    # |> debug("counts")
  end
end
