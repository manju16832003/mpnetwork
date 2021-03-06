defmodule Mpnetwork.User do
  @moduledoc false
  use Ecto.Schema
  use Coherence.Schema
  import Mpnetwork.Utils.Regexen

  @role_names_int ~w[root site_admin office_admin realtor readonly]a
  @role_names ["Root", "Site Admin", "Office Admin", "Realtor", "Read-only"]
  @roles_int for {v, k} <- @role_names_int |> Enum.with_index(), into: %{}, do: {k, v}
  @roles for {v, k} <- @role_names |> Enum.with_index(), into: %{}, do: {k, v}

  def roles_int, do: @roles_int
  def roles, do: @roles
  def role_names_int, do: @role_names_int
  def role_names, do: @role_names
  def map_role_id_to_role_name(id), do: roles()[id]
  def map_role_id_to_role_name_int(id), do: roles_int()[id]

  schema "users" do
    field(:username, :string, unique: true)
    field(:email, :string, unique: true)
    field(:name, :string)
    field(:office_phone, :string)
    field(:cell_phone, :string)
    field(:url, :string)
    field(:email_sig, :string)
    # field :password, :string, virtual: true #set via coherence_schema()
    # field :office_id, :integer, default: 1
    # Had to rename the following association to "broker"
    # after "office" became a boolean. Oops.
    belongs_to(:broker, Mpnetwork.Realtor.Office, foreign_key: :office_id)
    # Realtor
    field(:role_id, :integer, default: 3)
    # belongs_to :role, Mpnetwork.Realtor.Role, defaults: %{id: 3}
    has_many(:listings, Mpnetwork.Realtor.Listing, on_delete: :delete_all)
    has_many(:broadcasts, Mpnetwork.Realtor.Broadcast, on_delete: :delete_all)

    # adds :password_hash
    coherence_schema()

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    params =
      params
      |> copy_email_to_username_unless_username_exists
      |> default_role_to_realtor

    # |> check_constraint(:listings, name: "listings_user_id_fkey", message: "still has listings assigned to them")
    # |> check_constraint(:broadcasts, name: "broadcasts_user_id_fkey", message: "still has broadcasts assigned to them")
    model
    |> cast(
      params,
      [
        :username,
        :email,
        :name,
        :office_phone,
        :cell_phone,
        :office_id,
        :role_id,
        :url,
        :email_sig
      ] ++ coherence_fields()
    )
    |> validate_required([:username, :email, :office_id])
    |> validate_format(:email, email_regex())
    |> validate_format(:url, url_regex())
    |> validate_length(:username, max: 255, count: :codepoints)
    |> validate_length(:email, max: 255, count: :codepoints)
    |> validate_length(:name, max: 255, count: :codepoints)
    |> validate_length(:office_phone, max: 16, count: :codepoints)
    |> validate_length(:cell_phone, max: 16, count: :codepoints)
    |> validate_length(:url, max: 255, count: :codepoints)
    |> validate_length(:email_sig, max: 16384, count: :codepoints)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> foreign_key_constraint(:office_id)
    |> check_constraint(
      :listings,
      name: "attachments_listing_id_fkey",
      message: "still has listings and/or listing attachments assigned to them"
    )
    |> validate_coherence(params)
  end

  def changeset(model, params, :password) do
    model
    |> cast(
      params,
      ~w(password password_confirmation reset_password_token reset_password_sent_at)
    )
    |> validate_coherence_password_reset(params)
  end

  defp copy_email_to_username_unless_username_exists(params) do
    # for now the username will default to the email if not otherwise provided
    # for some reason had weird errors flipping between string/atom keys so here you go
    params =
      cond do
        params[:email] && !params[:username] ->
          Enum.into(%{username: params[:email]}, params)

        params["email"] && !params["username"] ->
          Enum.into(%{"username" => params["email"]}, params)

        true ->
          params
      end

    params
  end

  defp default_role_to_realtor(params) do
    params =
      cond do
        params[:email] && !params[:role_id] -> Enum.into(%{role_id: 3}, params)
        params["email"] && !params["role_id"] -> Enum.into(%{"role_id" => 3}, params)
        true -> params
      end

    params
  end
end
