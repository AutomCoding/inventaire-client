import behaviorsPlugin from 'modules/general/plugins/behaviors'
import forms_ from 'modules/general/lib/forms'
import groups_ from '../lib/groups'
import error_ from 'lib/error'
import PicturePicker from 'modules/general/views/behaviors/picture_picker'
import groupFormData from '../lib/group_form_data'
import getActionKey from 'lib/get_action_key'
import { updateLimit } from 'lib/textarea_limit'
import GroupUrl from '../lib/group_url'

const {
  ui: groupUrlUi,
  events: groupUrlEvents,
  LazyUpdateUrl
} = GroupUrl

export default Marionette.ItemView.extend({
  template: require('./templates/group_settings'),
  behaviors: {
    AlertBox: {},
    ElasticTextarea: {},
    PreventDefault: {},
    SuccessCheck: {},
    BackupForm: {},
    Toggler: {}
  },

  initialize () {
    this._lazyUpdateUrl = LazyUpdateUrl(this)
    return this.lazyDescriptionUpdate = _.debounce(updateLimit.bind(this, 'description', 'descriptionLimit', 5000), 200)
  },

  onRender () { return this.lazyDescriptionUpdate() },

  // Allows to define @_lazyUpdateUrl after events binding
  lazyUpdateUrl () { return this._lazyUpdateUrl() },

  serializeData () {
    const attrs = this.model.serializeData()
    return _.extend(attrs, {
      editName: this.editNameData(attrs.name),
      editDescription: groupFormData.description(attrs.description),
      userCanLeave: this.model.userCanLeave(),
      userIsLastUser: this.model.userIsLastUser(),
      searchability: groupFormData.searchability(attrs.searchable)
    })
  },

  editNameData (groupName) {
    return {
      nameBase: 'editName',
      field: {
        value: groupName,
        placeholder: groupName,
        classes: 'groupNameField'
      },
      button: {
        text: _.I18n('save')
      },
      check: true
    }
  },

  ui: _.extend({}, groupUrlUi, {
    editNameField: '#editNameField',
    description: '#description',
    descriptionLimit: '.descriptionLimit',
    saveCancel: '.saveCancel',
    searchabilityWarning: '.searchability .warning'
  }
  ),

  events: _.extend({}, groupUrlEvents, {
    'click #editNameButton': 'editName',
    'click a#changePicture': 'changePicture',
    'change #searchabilityToggler': 'toggleSearchability',
    'keyup #description': 'showSaveCancel',
    'click .cancelButton': 'cancelDescription',
    'click .saveButton': 'saveDescription',
    'click a.leave': 'leaveGroup',
    'click a.destroy': 'destroyGroup',
    'click #showPositionPicker': 'showPositionPicker',
    'keydown textarea#description' () { return this.lazyDescriptionUpdate() }
  }
  ),

  modelEvents: {
    // re-render to unlock the possibility to leave the group
    // if a new admin was selected
    'list:change:after': 'lazyRender',
    // Prevent having to listen for 'change:searchable' among others
    // aas it will be out-of-date only in case of a rollback
    rollback: 'lazyRender'
  },

  onShow () {
    this.listenTo(this.model, 'change:picture', this.LazyRenderFocus('#changePicture'))
    // re-render after a position was selected to display
    // the new geolocation status
    return this.listenTo(this.model, 'change:position', this.LazyRenderFocus('#showPositionPicker'))
  },

  LazyRenderFocus (focusSelector) { return this.lazyRender.bind(this, focusSelector) },

  editName () {
    const name = this.ui.editNameField.val()
    if (name != null) {
      return Promise.try(groups_.validateName.bind(this, name, '#editNameField'))
      .then(() => this._updateGroup('name', name, '#editNameField'))
      .catch(forms_.catchAlert.bind(null, this))
    }
  },

  _updateGroup (attribute, value, selector) {
    return app.request('group:update:settings', { model: this.model, attribute, value, selector })
  },

  changePicture () {
    return app.layout.modal.show(new PicturePicker({
      pictures: this.model.get('picture'),
      save: this._savePicture.bind(this),
      limit: 1,
      focus: '#changePicture'
    })
    )
  },

  _savePicture (pictures) {
    const picture = pictures[0]
    _.log(picture, 'picture')
    if (!_.isUserImg(picture)) {
      const message = 'couldnt save picture: requires a local user image url'
      throw error_.new(message, pictures)
    }

    return this.updateSettings({
      attribute: 'picture',
      value: picture,
      selector: '#changePicture'
    })
  },

  toggleSearchability (e) {
    const { checked } = e.currentTarget
    this.ui.searchabilityWarning.slideToggle()
    return this.updateSettings({
      attribute: 'searchable',
      value: checked
    })
  },

  updateSettings (update) {
    update.model = this.model
    return app.request('group:update:settings', update)
  },

  showSaveCancel (e) {
    const specialKey = getActionKey(e)
    if (!specialKey && !this._saveCancelShown) {
      this.ui.saveCancel.slideDown()
      return this._saveCancelShown = true
    }
  },

  cancelDescription () {
    this._saveCancelShown = false
    return this.render()
  },

  saveDescription () {
    this.ui.saveCancel.slideUp()
    this._saveCancelShown = false
    const description = this.ui.description.val()
    if (description != null) {
      return Promise.try(groups_.validateDescription.bind(this, description, '#description'))
      .then(() => this._updateGroup('description', description, '#description'))
      .catch(forms_.catchAlert.bind(null, this))
    }
  },

  leaveGroup () {
    const action = this.model.leave.bind(this.model)
    return this._leaveGroup('leave_group_confirmation', 'leave_group_warning', action)
  },

  destroyGroup () {
    const group = this.model
    const action = () => group.leave()
    .then(() => {
      // Dereference group model
      app.groups.remove(group)
      // And change page as staying on the same page would just display
      // the group as empty but accepting a join request
      return app.execute('show:inventory:network')
    }).catch(_.ErrorRethrow('destroyGroup action err'))

    return this._leaveGroup('destroy_group_confirmation', 'cant_undo_warning', action)
  },

  _leaveGroup (confirmationText, warningText, action) {
    const group = this.model
    const args = { groupName: group.get('name') }

    return app.execute('ask:confirmation', {
      confirmationText: _.i18n(confirmationText, args),
      warningText: _.i18n(warningText),
      action,
      // re-focus on the only existing anchor
      focus: '#groupControls a'
    }
    )
  },

  showPositionPicker () {
    return app.execute('show:position:picker:group', this.model, '#showPositionPicker')
  }
})
