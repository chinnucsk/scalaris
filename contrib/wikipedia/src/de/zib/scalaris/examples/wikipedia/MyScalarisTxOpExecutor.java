/**
 *  Copyright 2012 Zuse Institute Berlin
 *
 *   Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *   You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *   See the License for the specific language governing permissions and
 *   limitations under the License.
 */
package de.zib.scalaris.examples.wikipedia;

import java.util.List;

import com.ericsson.otp.erlang.OtpErlangException;

import de.zib.scalaris.AbortException;
import de.zib.scalaris.ConnectionException;
import de.zib.scalaris.executor.ScalarisOp;
import de.zib.scalaris.executor.ScalarisTxOpExecutor;
import de.zib.scalaris.TimeoutException;
import de.zib.scalaris.Transaction;
import de.zib.scalaris.UnknownException;
import de.zib.scalaris.RequestList;
import de.zib.scalaris.Transaction.ResultList;

/**
 * Executes multiple {@link ScalarisOp} operations in multiple phases only
 * sending requests to Scalaris once per work phase.
 * 
 * In addition to {@link ScalarisTxOpExecutor}, also collects info about all
 * involved keys.
 * 
 * @author Nico Kruber, kruber@zib.de
 */
public class MyScalarisTxOpExecutor extends ScalarisTxOpExecutor {
    protected final List<InvolvedKey> involvedKeys;

    /**
     * Creates a new executor.
     * 
     * @param scalaris_tx
     *            the Scalaris connection to use
     * @param involvedKeys
     *            list of all involved keys
     */
    public MyScalarisTxOpExecutor(Transaction scalaris_tx,
            List<InvolvedKey> involvedKeys) {
        super(scalaris_tx);
        this.involvedKeys = involvedKeys;
    }

    /**
     * Executes the given requests and records all involved keys.
     * 
     * @param requests
     *            a request list to execute
     * 
     * @return the results from executing the requests
     * 
     * @throws OtpErlangException
     *             if an error occurred verifying a result from previous
     *             operations
     * @throws UnknownException
     *             if an error occurred verifying a result from previous
     *             operations
     */
    @Override
    protected ResultList executeRequests(RequestList requests)
            throws ConnectionException, TimeoutException, AbortException,
            UnknownException {
        ScalarisDataHandler.addInvolvedKeys(involvedKeys, requests.getRequests());
        return super.executeRequests(requests);
    }

    /**
     * @return the involvedKeys
     */
    public List<InvolvedKey> getInvolvedKeys() {
        return involvedKeys;
    }
}
