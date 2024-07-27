defmodule PollyWeb.PollLive.Index do
  use PollyWeb, :live_view

  alias Polly.Polls
  alias Polly.Schema.Poll

  @topic Polly.Constants.encode(:polls_topic)
  @new_poll_event Polly.Constants.encode(:new_poll_event)

  @impl true
  def mount(_params, _session, socket) do
    # we subscribe to a topic for the index page, this way
    # when someone votes we could update this page
    PollyWeb.Endpoint.subscribe(@topic)

    # Though of using streams here but as per chris Mccord's
    # recent comment streams dont support a full update i.e.
    # cannot replace a stream with a new stream
    {:ok, assign(socket, :polls, Polls.list_polls())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Poll")
    |> assign(:poll, %Poll{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Polls")
    |> assign(:poll, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    poll = Polly.PollsManager.get_poll!(id)
    changeset = Polly.PollsManager.change_poll(poll)
    socket
    |> assign(:page_title, "Edit Poll")
    |> assign(:poll, poll)
    |> assign(:changeset, changeset)
  end


  @impl true
  def handle_info(%{topic: @topic, payload: _state}, socket) do
    # we basically update the whole list of polls
    {:noreply, update(socket, :polls, fn _polls -> Polls.list_polls() end)}
  end

  @impl true
  def handle_info({PollyWeb.PollLive.FormComponent, {:saved, poll}}, socket) do
    # broadcast a new poll event so other users can see updated poll list
    # in real time
    PollyWeb.Endpoint.broadcast(@topic, @new_poll_event, poll)
    {:noreply, update(socket, :polls, fn _polls -> Polls.list_polls() end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Polls
      <:actions>
        <.link navigate={~p"/polls/new"}>
          <.button>New Poll</.button>
        </.link>
      </:actions>
    </.header>

    <.table id="polls" rows={@polls} row_click={fn {_id, poll} -> JS.navigate(~p"/polls/#{poll}") end}>
      <:col :let={{_id, poll}} label="Title"><%= poll.title %></:col>
      <:col :let={{_id, poll}} label="Total Votes"><%= poll.total_votes %></:col>
      <:action :let={{_id, poll}}>
        <.link navigate={~p"/polls/#{poll}/edit"}>
          <.button>Edit</.button>
        </.link>
        <div class="sr-only">
          <.link navigate={~p"/polls/#{poll}"}>Show</.link>
        </div>
      </:action>
    </.table>

    <.modal :if={@live_action in [:new, :edit]} id="poll-modal" show on_cancel={JS.patch(~p"/")}>
      <.live_component
        module={PollyWeb.PollLive.FormComponent}
        id={@poll.id || :new}
        title={@page_title}
        action={@live_action}
        poll={@poll}
        patch={~p"/"}
      />
    </.modal>
    """
  end

end
