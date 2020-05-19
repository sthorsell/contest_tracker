import React, { Component, useEffect } from "react";

import {Info} from '@material-ui/icons';
import { Grid, IconButton, Typography } from '@material-ui/core';
import { Dialog, DialogTitle, DialogContent } from '@material-ui/core';
import { Table, TableBody, TableCell, TableHead, TablePagination, TableRow } from '@material-ui/core'


function Summary(props) {
  const { open, onClose, contest } = props
  const [payoutPage, setPayoutPage] = React.useState(0);
  const [filteredPayouts, setFilteredPayouts] = React.useState([])

  const handleClose = () => {
    onClose();
  };

  useEffect(() => {
    const start = payoutPage * 5
    setFilteredPayouts(() => contest.payouts.slice(start, start + 5))
  }, [payoutPage]);

  return (
    <Dialog onClose={handleClose} aria-labelledby='contest-summary' open={open} PaperProps={{style: {margin: '8px'}}}>
      <DialogTitle id='simple-dialog-title' disableTypography={true}><Typography variant="subtitle2">{contest.name}</Typography></DialogTitle>
      <DialogContent dividers>
        <Grid container justify="center">
          <Grid item xs={6}>
            <Typography variant="body2">Entry Fee: ${contest.entryFee}</Typography>
          </Grid>
          <Grid item xs={6}>
            <Typography variant="body2">Total Entries: {Number(contest.entryCount).toLocaleString()}</Typography>
          </Grid>
          <Grid item xs={12}>
            <Table aria-label="payouts">
              <TableHead>
                <TableRow>
                  <TableCell>Position</TableCell>
                  <TableCell align="right">Prize($)</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {filteredPayouts.map((row, i) => (
                  <TableRow key={i}>
                    <TableCell component="th" scope="row">
                      {
                        row.min === row.max ? 
                        <React.Fragment>{row.min}</React.Fragment> :
                        <React.Fragment>{row.min} - {row.max}</React.Fragment>
                      }
                    </TableCell>
                    <TableCell align="right">{Number(row.amount).toLocaleString()}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <TablePagination
              component="div"
              count={contest.payouts.length}
              rowsPerPage={5}
              rowsPerPageOptions={[]}
              page={payoutPage}
              onChangePage={(event, page) => setPayoutPage(page)}
            />
          </Grid>
        </Grid>
      </DialogContent>
    </Dialog>
  );
}

export default function Contest() {
  const [contest, setContest] = React.useState(null);
  const [open, setOpen] = React.useState(false);

  const handleClickOpen = () => {
    setOpen(true);
  };

  const handleClose = () => {
    setOpen(false);
  };

  useEffect(() => {
    fetch('api/summary')
      .then(response => response.json())
      .then(data => setContest(data));
  }, []);

  const loading = <Typography variant="h6">Loading...</Typography>
  

  return(
    <Grid item xs={12}>
      {
        contest ? 
        <Grid container alignItems="center">
          <Grid item xs={false} md={4} />
          <Grid item xs={10} md={4}>
            <Typography variant="subtitle2" noWrap>
                {contest.name}                
            </Typography>
          </Grid>
          <Grid item xs={2} md={4}>
            <IconButton onClick={handleClickOpen}>
              <Info style={{ fontSize: 20 }} />
            </IconButton>
          </Grid>
          <Summary open={open} onClose={handleClose} contest={contest} />
        </Grid> :
        'Loading...'
      }     
    </Grid>
  );
}
