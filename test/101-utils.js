import 'should'
import _ from './utils_builder'

describe('Utils', () => {
  describe('cutBeforeWord', () => {
    const text = 'Lorem ipsum dolor sit amet, consectetur adipisicing elit'
    const result = _.cutBeforeWord(text, 24)
    it('should return a string shorter or egal to the limit', done => {
      (result.length <= 24).should.equal(true)
      done()
    })
    it('should cut between words', done => {
      result.should.equal('Lorem ipsum dolor sit')
      done()
    })
  })
})
