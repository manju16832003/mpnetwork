defmodule Mpnetwork.Web.AttachmentController do
  use Mpnetwork.Web, :controller

  alias Mpnetwork.Listing

  require ExImageInfo

  defp get_cached(id) do
    id = if is_binary(id), do: String.to_integer(id), else: id
    attachment = case Cachex.get(:attachment_cache, id, fallback: &Listing.get_attachment!/1) do
      # {:ok, val}     -> val
      # {:loaded, val} -> val
      {_, val}       -> val
    end
    # touch it in order to turn LRW policy into an LRU policy
    Cachex.touch(:attachment_cache, id)
    attachment
  end

  defp get_cached_and_purge(id) do
    id = if is_binary(id), do: String.to_integer(id), else: id
    attachment = case Cachex.get(:attachment_cache, id, fallback: &Listing.get_attachment!/1) do
      # {:ok, val}     -> val
      # {:loaded, val} -> val
      {_, val}       -> val
    end
    Cachex.del(:attachment_cache, id)
    attachment
  end

  defp convert_attachment_params_to_attachment_data(attachment_params) do
    # IO.inspect attachment_params
    # %{"data" => %Plug.Upload{content_type: "image/jpeg",
    # filename: "scumbag-steve-if-you-find-the-mirror-of-the-heart-dull-the-rust-has-not-been-cleared-from-its-face.jpg",
    # path: "/var/folders/7w/2lx70htn0nn9rnnq0cmyppfr0000gn/T//plug-1497/multipart-635613-44500-4"},
    # "listing_id" => "2", "primary" => "false"}
    binary_data_loc = attachment_params["data"].path
    binary_data_orig_filename = attachment_params["data"].filename
    # don't trust content type from the browser I guess, lol
    # binary_data_content_type = attachment_params["data"].content_type
    binary_data = File.read!(binary_data_loc)
    {binary_data_content_type, width_pixels, height_pixels} = 
      case ExImageInfo.info(binary_data) do
        nil          -> {attachment_params["data"].content_type, nil, nil}
        {a, b, c, _} -> {a, b, c}
      end
    Enum.into(%{
      "data" => binary_data,
      "content_type" => binary_data_content_type,
      "original_filename" => binary_data_orig_filename,
      # note that these are all the image types that ExImageInfo recognizes
      "is_image" => case binary_data_content_type do
                      "image/jpeg" -> true
                      "image/gif"  -> true
                      "image/png"  -> true
                      "image/bmp"  -> true
                      "image/psd"  -> true
                      "image/tiff" -> true
                      "image/webp" -> true
                      _            -> false
                    end,
      "sha256_hash" => :crypto.hash(:sha256, binary_data), #note that this is the raw binary, not |> Base.encode16
      "width_pixels" => width_pixels,
      "height_pixels" => height_pixels
    }, attachment_params)
  end

  def index(conn, _params) do
    attachments = Listing.list_attachments()
    render(conn, "index.html", attachments: attachments)
  end

  def new(conn, _params) do
    changeset = Listing.change_attachment(%Mpnetwork.Listing.Attachment{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"attachment" => attachment_params}) do
    attachment_params = convert_attachment_params_to_attachment_data(attachment_params)
    # IO.inspect attachment_params
    case Listing.create_attachment(attachment_params) do
      {:ok, attachment} ->
        conn
        |> put_flash(:info, "Attachment created successfully.")
        |> redirect(to: attachment_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  # note: this actually delivers the binary data, not an HTML view
  def show(conn, %{"id" => id}) do
    import Plug.Conn
    attachment = get_cached(id)
    # obey the If-None-Match header and send a Not Modified if they're the same
    expected_hash = get_req_header(conn, "if-none-match")
    actual_hash   = Base.encode16(attachment.sha256_hash)
    if Enum.member?(expected_hash, actual_hash) do
      conn
      |> send_resp(304, "")
    else
      conn
      |> put_resp_header("content-type", attachment.content_type)
      |> put_resp_header("content-disposition", "filename=\"#{attachment.original_filename}\"")
      |> put_resp_header("ETag", Base.encode16(attachment.sha256_hash) )
      # |> delete_resp_header("set-cookie") # don't need to send cookie data with files
      # Can't seem to delete the set-cookie response header being sent with attachments.
      # Tabling for now. Probably has to do with the secure routes, but I did try
      # piping just the show action through an empty pipeline.
      |> send_resp(200, attachment.data)
    end
  end

  def edit(conn, %{"id" => id}) do
    attachment = get_cached(id)
    changeset = Listing.change_attachment(attachment)
    render(conn, "edit.html", attachment: attachment, changeset: changeset)
  end

  def update(conn, %{"id" => id, "attachment" => attachment_params}) do
    attachment = get_cached_and_purge(id)
    attachment_params = convert_attachment_params_to_attachment_data(attachment_params)

    case Listing.update_attachment(attachment, attachment_params) do
      {:ok, attachment} ->
        conn
        |> put_flash(:info, "Attachment updated successfully.")
        |> redirect(to: attachment_path(conn, :show, attachment))
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", attachment: attachment, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    attachment = get_cached_and_purge(id)
    {:ok, _attachment} = Listing.delete_attachment(attachment)

    conn
    |> put_flash(:info, "Attachment deleted successfully.")
    |> redirect(to: attachment_path(conn, :index))
  end
end
