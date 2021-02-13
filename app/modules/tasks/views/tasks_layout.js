import { isModel } from 'lib/boolean_tests'
import { i18n } from 'modules/user/lib/i18n'
import preq from 'lib/preq'
import getNextTask from '../lib/get_next_task'
import CurrentTask from './current_task'
import RelativeTasks from './relative_tasks'
import Task from '../models/task'
import error_ from 'lib/error'
import forms_ from 'modules/general/lib/forms'
import { startLoading, stopLoading } from 'modules/general/plugins/behaviors'
import tasksLayoutTemplate from './templates/tasks_layout.hbs'
import '../scss/tasks_layout.scss'

const previousTasks = []

export default Marionette.LayoutView.extend({
  id: 'tasksLayout',
  attributes: {
    // Allow the view to be focused by clicking on it, thus being able to listen
    // for keydown events
    tabindex: '0'
  },

  template: tasksLayoutTemplate,
  regions: {
    currentTask: '#currentTask',
    relativeTasks: '#relativeTasks'
  },

  ui: {
    homonymsCount: '.homonymsCount',
    relativesToggler: '.toggle-relatives .fa-chevron-down'
  },

  behaviors: {
    AlertBox: {},
    Loading: {}
  },

  onShow () {
    const { task } = this.options
    if (isModel(task)) {
      this.showTask(Promise.resolve(task))
    } else if (task != null) {
      this.showFromId(task)
    } else {
      this.showNextTask()
    }
  },

  showNextTask (params = {}) {
    const { spinner } = params
    if (spinner != null) startLoading.call(this, spinner)
    const offset = app.request('querystring:get', 'offset')
    const nextTask = getNextTask({ previousTasks, offset, lastTaskModel: this.currentTaskModel })
    if (spinner != null) stopLoading.call(this, spinner)
    this.showTask(nextTask)
  },

  showTask (taskModelPromise) {
    return taskModelPromise
    .then(this.showFromModel.bind(this))
    .catch(app.Execute('show:error'))
  },

  showFromModel (model) {
    this.previousTask = this.currentTaskModel
    this.currentTaskModel = model

    const state = model.get('state')
    if (state != null) {
      const err = error_.new('this task has already been treated', 400, { model, state })
      return app.execute('show:error:other', err, 'tasks_layout showFromModel')
    }

    previousTasks.push(model.get('_id'))

    this._grabSuspectPromise = model.grabSuspect()

    return Promise.all([
      this.showCurrentTask(model),
      this.showRelativeTasks(model)
    ])
    .catch(app.Execute('show:error'))
  },

  showCurrentTask (model) {
    return Promise.all([
      this._grabSuspectPromise,
      model.grabSuggestion()
    ])
    .then(() => {
      this.currentTask.show(new CurrentTask({ model }))
      app.navigateFromModel(model)
      this.focusOnControls()
    })
  },

  showRelativeTasks (model) {
    return this._grabSuspectPromise
    .then(model.getOtherSuggestions.bind(model))
    .then(() => {
      this.relativeTasks.show(new RelativeTasks({
        collection: model.suspect.mergeSuggestions,
        currentTaskModel: model
      }))
      this.updateRelativesCount(model)
    })
  },

  showFromId (id) { this.showTask(getTaskById(id)) },

  focusOnControls () {
    // Take focus so that we can listen for keydown events
    this.$el.focus()
  },

  events: {
    'click .dismiss': 'dismiss',
    'click .merge': 'merge',
    'click .next': 'showNextTaskFromButton',
    'click .controls': 'toggleRelatives',
    keydown: 'triggerActionByKey'
  },

  dismiss (e) {
    this.action('dismiss')
    this.showNextTask({ spinner: '.dismiss' })
    e?.stopPropagation()
  },

  merge (e) {
    this.action('merge')
    this.showNextTask({ spinner: '.merge' })
    e?.stopPropagation()
  },

  action (actionName) {
    this.currentTaskModel[actionName]()
    .catch(this.handleActionError.bind(this, this.currentTaskModel))
  },

  handleActionError (actionTaskModel, err) {
    error_.complete(err, '.alertWrapper', false)
    forms_.catchAlert(this, err)
    this.showFromModel(actionTaskModel)
  },

  showNextTaskFromButton (e) {
    this.showNextTask({ spinner: '.next' })
    e?.stopPropagation()
  },

  triggerActionByKey (e) {
    // Prevent interpretting browser shortkeys such as Alt+D or Ctrl+R
    // as action keys
    if (e.altKey || e.ctrlKey || e.metaKey) return

    if (e.key === 'd') this.dismiss()
    else if (e.key === 'm') this.merge()
    else if (e.key === 'w') this.mergeAndDeduplicate()
    else if (e.key === 'n') this.showNextTaskFromButton()
    else if (e.key === 'r') this.toggleRelatives()
    else if (/^\d+$/.test(e.key)) {
      this.showRelativeFromIndex(parseInt(e.key) - 1)
    }
  },

  toggleRelatives () {
    this.$el.toggleClass('wrapped-controls')
    this.ui.relativesToggler.toggleClass('toggled')
  },

  showRelativeFromIndex (index) {
    const el = this.relativeTasks.$el.find('.relative-task')[index]
    const taskId = el?.attributes['data-task-id'].value
    if (taskId != null) this.showFromId(taskId)
  },

  updateRelativesCount (task) {
    let risk, text
    const { mergeSuggestions: suggestions } = task.suspect
    const currentSuggestionScore = task.get('globalScore')
    const highestSuggestionsScore = suggestions.getHighestScore(task.id)
    // Remove the current task from the count
    const count = suggestions.length - 1
    if (count === 0) {
      text = i18n('has no homonym')
      risk = 'none'
      this.ui.relativesToggler.css('visibility', 'hidden')
    } else {
      text = i18n('homonyms_count', { smart_count: count })
      this.ui.relativesToggler.css('visibility', null)
      if ((currentSuggestionScore - highestSuggestionsScore) < 10) {
        risk = 'high'
      } else {
        risk = 'medium'
      }
    }

    this.ui.homonymsCount.text(text)
    this.ui.homonymsCount.attr('data-risk', risk)
  }
})

const getTaskById = async id => {
  const { tasks } = await preq.get(app.API.tasks.byIds(id))
  const task = tasks[0]
  if (task != null) return new Task(task)
  else throw error_.new('not found', 404, { id })
}
