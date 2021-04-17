defmodule NydusOperator.Controller.V1.External do
  @moduledoc """
  HelloOperator: Greeting CRD.
  ## Kubernetes CRD Spec
  By default all CRD specs are assumed from the module name, you can override them using attributes.
  ### Examples
  ```
  # Kubernetes API version of this CRD, defaults to value in module name
  @version "v2alpha1"
  # Kubernetes API group of this CRD, defaults to "hello-operator.example.com"
  @group "kewl.example.io"
  The scope of the CRD. Defaults to `:namespaced`
  @scope :cluster
  CRD names used by kubectl and the kubernetes API
  @names %{
    plural: "foos",
    singular: "foo",
    kind: "Foo"
  }
  ```
  ## Declare RBAC permissions used by this module
  RBAC rules can be declared using `@rule` attribute and generated using `mix bonny.manifest`
  This `@rule` attribute is cumulative, and can be declared once for each Kubernetes API Group.
  ### Examples
  ```
  @rule {apiGroup, resources_list, verbs_list}
  @rule {"", ["pods", "secrets"], ["*"]}
  @rule {"apiextensions.k8s.io", ["foo"], ["*"]}
  ```
  """
  require Logger
  use Bonny.Controller

  @group "nydus.mrchypark.github.io"
  @version "v1"

  @scope :namespaced
  @names %{
    plural: "externals",
    singular: "external",
    kind: "External",
    shortNames: ["ext", "extl"]
  }

  @rule {"apps", ["deployments"], ["*"]}

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec reconcile(map()) :: :ok | :error
  @impl Bonny.Controller
  def reconcile(payload) do
    track_event(:reconcile, payload)
    :ok
  end

  @doc """
  Creates a kubernetes `deployment` and `service` that runs a "Hello, World" app.
  """
  @spec add(map()) :: :ok | :error
  @impl Bonny.Controller
  def add(payload) do
    track_event(:add, payload)
    resources = parse(payload)
    tem = K8s.Client.create(resources.deployment)
    track_event(:modify_template, tem)

    with tem |> run do
      :ok
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Updates `deployment` and `configmap` resources.
  """
  @spec modify(map()) :: :ok | :error
  @impl Bonny.Controller
  def modify(payload) do
    track_event(:modify, payload)
    resources = parse(payload)
    tem = K8s.Client.patch(resources.deployment)
    track_event(:modify_template, tem)

    with tem |> run do
      :ok
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Deletes `deployment` and `service` resources.
  """
  @spec delete(map()) :: :ok | :error
  @impl Bonny.Controller
  def delete(payload) do
    track_event(:delete, payload)
    resources = parse(payload)

    with {:ok, _} <- K8s.Client.delete(resources.deployment) |> run do
      :ok
    else
      {:error, error} -> {:error, error}
    end
  end

  defp parse(%{
         "metadata" => %{"name" => name, "namespace" => ns, "labels" => labels},
         "spec" => %{
           "metadata" => %{"annotations" => annotations},
           "nydus" => config
         }
       }) do
    deployment = gen_deployment(name, ns, labels, annotations, config)

    %{
      deployment: deployment
    }
  end

  alias NydusOperator.Resource.Default.Deployment

  defp gen_deployment(name, ns, labels, annotations, config) do
    config =
      config
      |> get_nydus_values

    Deployment.new(name, ns, labels, annotations, config)
  end

  defp get_nydus_values(nydus) do
    nydus
    |> flatten()
  end

  defp run(%K8s.Operation{} = op),
    do: K8s.Client.run(op, Bonny.Config.cluster_name())

  defp track_event(type, resource),
    do: Logger.info("#{type}: \n #{inspect(resource, pretty: true)}")

  def flatten(map) when is_map(map) do
    map
    |> to_list_of_tuples
    |> Enum.into(%{})
  end

  defp to_list_of_tuples(m) do
    m
    |> Enum.map(&process/1)
    |> List.flatten()
  end

  defp process({key, sub_map}) when is_map(sub_map) do
    for {sub_key, value} <- flatten(sub_map) do
      {"#{key}-#{sub_key}", value}
    end
  end

  defp process(next), do: next
end
