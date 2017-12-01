defmodule MpnetworkWeb.PageController do
  use MpnetworkWeb, :controller

  alias Mpnetwork.{Realtor, Listing, Permissions}

  def index(conn, _params) do
    u = conn.assigns.current_user
    broadcasts = Realtor.list_latest_broadcasts(4) |> Enum.reverse
    listings = Realtor.list_latest_listings(nil, 20)
    draft_listings = if Permissions.office_admin_or_site_admin?(u) do
      Realtor.list_latest_draft_listings(conn.assigns.current_office)
    else
      Realtor.list_latest_draft_listings(u)
    end
    primary_images = Listing.primary_images_for_listings(listings)
    draft_primaries = Listing.primary_images_for_listings(draft_listings)
    render(conn, "index.html",
      broadcasts: broadcasts,
      listings: listings,
      primaries: primary_images,
      draft_listings: draft_listings,
      draft_primaries: draft_primaries
    )
  end

  def bare_session_redirect(conn, _params) do
    redirect(conn, to: page_path(conn, :index))
  end

end
