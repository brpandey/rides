defmodule Rides.ProviderRepoTest do
  use ExUnit.Case

  alias Rides.{Mapper.Provider, Repo}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  @valid_provider_attr1 %{name: "Kamakurashares"}
  @valid_provider_attr2 %{name: "GinzaRides"}

  @invalid_provider_attr1 %{name: nil}
  @invalid_provider_attr2 %{name: 3}

  test "check successful creation of valid providers" do
    {:ok, %Provider{}} = Provider.create(@valid_provider_attr1)
    {:ok, %Provider{}} = Provider.create(@valid_provider_attr2)
  end

  test "check unsuccessful creation of duplicate provider" do
    {:ok, %Provider{}} = Provider.create(@valid_provider_attr1)
    {:error, %Ecto.Changeset{errors: e}} = Provider.create(@valid_provider_attr1)

    assert [name: {"has already been taken", []}] = e
  end

  test "check unsuccessful creation of nil provider" do
    {:error, %Ecto.Changeset{errors: e}} = @invalid_provider_attr1 |> Provider.create()

    assert [name: {"can't be blank", [validation: :required]}] = e
  end

  test "check unsuccessful creation of provider with invalid type" do
    {:error, %Ecto.Changeset{errors: e}} = @invalid_provider_attr2 |> Provider.create()

    assert [name: {"is invalid", [type: :string, validation: :cast]}] = e
  end
end
