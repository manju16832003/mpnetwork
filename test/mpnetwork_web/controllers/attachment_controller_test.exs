defmodule MpnetworkWeb.AttachmentControllerTest do
  # use ExUnit.Case, async: true

  import Ecto.Query, warn: false

  use MpnetworkWeb.ConnCase, async: true

  alias Mpnetwork.{Listing, Upload, Repo}
  alias Listing.Attachment
  import Mpnetwork.Test.Support.Utilities

  # supposedly a png of a red dot
  @test_attachment_binary_data_base64 "iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="
  @test_attachment_binary_data @test_attachment_binary_data_base64 |> Base.decode64!()
  # supposedly a gif
  @test_attachment_new_binary_data_base64 "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
  @test_attachment_new_binary_data @test_attachment_new_binary_data_base64 |> Base.decode64!()

  @post_attachment_create_attrs %{
    sha256_hash: Upload.sha256_hash(@test_attachment_binary_data),
    content_type: "image/png",
    data: %Upload{
      content_type: "image/png",
      filename: "test.png",
      binary: @test_attachment_binary_data
    },
    original_filename: "some_original_filename.png",
    is_image: true,
    primary: false
  }
  @post_update_attrs %{
    sha256_hash: Upload.sha256_hash(@test_attachment_new_binary_data),
    content_type: "image/gif",
    data: %Upload{
      content_type: "image/gif",
      filename: "test.gif",
      binary: @test_attachment_new_binary_data
    },
    original_filename: "some_new_filename.gif",
    is_image: true,
    primary: true
  }
  # @attachment_create_attrs Enum.into(%{data: @test_attachment_binary_data}, @post_attachment_create_attrs)
  # @update_attrs Enum.into(%{data: @test_attachment_new_binary_data}, @post_update_attrs)
  # @invalid_attrs %{content_type: nil, data: nil, height_pixels: nil, original_filename: nil, is_image: nil, primary: true, sha256_hash: nil, width_pixels: nil}
  @invalid_post_attrs Enum.into(%{data: nil}, @post_attachment_create_attrs)

  setup %{conn: conn} do
    office = office_fixture()
    user = user_fixture(%{office: office, office_id: office.id})
    conn = assign(conn, :current_office, office)
    {:ok, conn: assign(conn, :current_user, user), user: user}
  end

  def attachment_fixture(:listing, user \\ user_fixture()) do
    listing = fixture(:listing, user)
    {listing, fixture(:attachment, %{listing_id: listing.id, listing: listing})}
  end

  test "lists all entries on index", %{conn: conn} do
    listing = fixture(:listing, conn.assigns.current_user)
    conn = get(conn, attachment_path(conn, :index, listing_id: listing.id))
    assert html_response(conn, 200) =~ "Attachments for #{listing.address}"
  end

  test "renders form for new attachments", %{conn: conn} do
    listing = fixture(:listing, conn.assigns.current_user)
    conn = get(conn, attachment_path(conn, :new, listing_id: listing.id))
    assert html_response(conn, 200) =~ "New Attachment(s)"
  end

  # holy crap, was this test a pain to write. FYI
  test "creates attachment and redirects to show when data is valid, also returns 304 on re-request",
       %{conn: initial_conn} do
    conn = initial_conn
    listing = fixture(:listing, conn.assigns.current_user)

    conn =
      post(
        conn,
        attachment_path(conn, :create),
        attachment: Enum.into(%{listing_id: listing.id, listing: listing}, @post_attachment_create_attrs)
      )

    # had to do this since redirected_params won't parse querystring params.
    %{"listing_id" => listing_id} =
      Regex.named_captures(~r/listing_id=(?<listing_id>[0-9]+)/, redirected_to(conn))

    listing_id = String.to_integer(listing_id)
    assert listing_id == listing.id
    assert redirected_to(conn) == attachment_path(conn, :index, listing_id: listing.id)

    [%Attachment{id: attachment_id} = attachment] =
      Repo.all(from(a in Attachment, where: a.listing_id == ^listing_id))

    conn = initial_conn
    conn = get(conn, attachment_path(conn, :show, attachment_id))
    assert response(conn, 200) =~ @test_attachment_binary_data
    conn = initial_conn
    # the following header triggers the ETag comparison server-side
    conn = put_req_header(conn, "if-none-match", Base.encode16(attachment.sha256_hash))
    conn = get(conn, attachment_path(conn, :show, attachment_id))
    assert response(conn, 304)
  end

  test "does not create attachment and renders errors when data is invalid", %{conn: conn} do
    listing = fixture(:listing, conn.assigns.current_user)

    conn =
      post(
        conn,
        attachment_path(conn, :create),
        attachment: Enum.into(%{listing_id: listing.id}, @invalid_post_attrs)
      )

    assert html_response(conn, 200) =~ "New Attachment(s)"
  end

  test "renders form for editing chosen attachment", %{conn: conn} do
    {_listing, attachment} = attachment_fixture(:listing, conn.assigns.current_user)
    conn = get(conn, attachment_path(conn, :edit, attachment))
    assert html_response(conn, 200) =~ "Editing Attachment"
  end

  test "updates chosen attachment and redirects when data is valid", %{conn: conn} do
    initial_conn = conn
    {listing, attachment} = attachment_fixture(:listing, conn.assigns.current_user)
    conn = put(conn, attachment_path(conn, :update, attachment), attachment: @post_update_attrs)
    assert redirected_to(conn) == attachment_path(conn, :index, listing_id: listing.id)
    conn = initial_conn
    conn = get(conn, attachment_path(conn, :show, attachment))
    assert response(conn, 200) == @test_attachment_new_binary_data
  end

  test "does not update chosen attachment and renders errors when data is invalid", %{conn: conn} do
    {_listing, attachment} = attachment_fixture(:listing, conn.assigns.current_user)
    conn = put(conn, attachment_path(conn, :update, attachment), attachment: @invalid_post_attrs)
    assert html_response(conn, 200) =~ "Editing Attachment"
  end

  test "deletes chosen attachment", %{conn: conn} do
    initial_conn = conn
    {listing, attachment} = attachment_fixture(:listing, conn.assigns.current_user)
    conn = delete(conn, attachment_path(conn, :delete, attachment))
    assert redirected_to(conn) == attachment_path(conn, :index, listing_id: listing.id)
    conn = initial_conn

    assert_error_sent(404, fn ->
      get(conn, attachment_path(conn, :show, attachment))
    end)
  end

  test "shows attachment based on base64-encoded sha256 hash of attachment", %{conn: conn} do
    {_listing, attachment} = attachment_fixture(:listing, conn.assigns.current_user)
    conn = get(conn, attachment_path(conn, :show, attachment.sha256_hash |> Base.url_encode64()))
    assert response(conn, 200) == @test_attachment_binary_data
  end
end
