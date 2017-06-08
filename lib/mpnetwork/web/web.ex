defmodule Mpnetwork.Web do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use Mpnetwork.Web, :controller
      use Mpnetwork.Web, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """


  def controller do
    quote do
      use Phoenix.Controller, namespace: Mpnetwork.Web
      import Plug.Conn
      import Mpnetwork.Web.Router.Helpers
      import Mpnetwork.Web.Gettext
      # import Coherence current_user and logged_in? into all controllers
      import Coherence, only: [current_user: 1, logged_in?: 1]
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "lib/mpnetwork/web/templates",
                        namespace: Mpnetwork.Web

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import Mpnetwork.Web.Router.Helpers
      import Mpnetwork.Web.ErrorHelpers
      import Mpnetwork.Web.Gettext
      # custom global helpers
      import Mpnetwork.Web.GlobalHelpers
      # import Coherence current_user and logged_in? into all controllers
      import Coherence, only: [current_user: 1, logged_in?: 1]
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import Mpnetwork.Web.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
